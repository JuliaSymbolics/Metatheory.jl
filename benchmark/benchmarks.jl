using BenchmarkTools
using Metatheory
using Metatheory.Library

const SUITE = BenchmarkGroup()

function simplify(ex, theory, params = SaturationParams(), postprocess = identity)
  g = EGraph(ex)
  saturate!(g, theory, params)
  res = extract!(g, astsize)
  postprocess(res), g
end


function report_size(bench, g)
  n_classes = length(g.classes)
  n_nodes = sum(length(c.nodes) for c in values(g.classes))
  n_memo = length(g.memo)
  println("$bench n_classes: $n_classes, n_nodes: $n_nodes, n_memo: $n_memo")
end

check_result(result, expected,_) = @assert expected == result
function check_result(result::Tuple, expected, benchname)
  expr, g = result
  report_size(benchname, g)
  @assert expected == expr
end

include(joinpath(dirname(pathof(Metatheory)), "../examples/prove.jl"))
include(joinpath(dirname(pathof(Metatheory)), "../examples/basic_maths_theory.jl"))
include(joinpath(dirname(pathof(Metatheory)), "../examples/propositional_logic_theory.jl"))
include(joinpath(dirname(pathof(Metatheory)), "../examples/calculational_logic_theory.jl"))
include(joinpath(dirname(pathof(Metatheory)), "../examples/while_superinterpreter_theory.jl"))

SUITE["egraph"] = BenchmarkGroup(["egraphs"])
SUITE["egraph"]["constructor"] = @benchmarkable EGraph()

rand_letter() = Symbol(rand('a':'z'))

function nested_expr(level)
  if level > 0
    :(($(rand_letter()))($(rand_letter())) + $(rand_letter()) + $(rand(1:100)) * $(nested_expr(level - 1)))
  else
    rand_letter()
  end
end

SUITE["egraph"]["addexpr"] = @benchmarkable EGraph($(nested_expr(2000)))


# ==================================================================

SUITE["basic_maths"] = BenchmarkGroup(["egraphs"])


simpl1_math = :(a + b + (0 * c) + d)
SUITE["basic_maths"]["simpl1"] = begin
  quoted_expr = :(simplify(
    simpl1_math,
    maths_theory,
    (SaturationParams(; timer = false)),
    postprocess_maths,
  ))
  @eval check_result($quoted_expr, :(a + b + d), "basic_maths/simpl1")
  @eval @benchmarkable $quoted_expr
end

simpl2_math = :(0 + (1 * foo) * 0 + (a * 0) + a)
SUITE["basic_maths"]["simpl2"] = begin
  quoted_expr = :(simplify(simpl2_math, maths_theory, SaturationParams(), postprocess_maths))
  @eval check_result($quoted_expr, :a, "basic_maths/simpl2")
  @eval @benchmarkable $quoted_expr
end

# ==================================================================

SUITE["prop_logic"] = BenchmarkGroup(["egraph", "logic"])

ex_orig = :(((p ⟹ q) && (r ⟹ s) && (p || r)) ⟹ (q || s))
ex_logic = rewrite(ex_orig, impl)

SUITE["prop_logic"]["rewrite"] = @benchmarkable rewrite($ex_orig, $impl)

SUITE["prop_logic"]["prove1"] = begin 
  quoted_expr = :(prove(propositional_logic_theory, ex_logic, 3, 6))
  @eval check_result($quoted_expr, true, "prop_logic/prove1")
  @eval @benchmarkable $quoted_expr
end

ex_demorgan = :(!(p || q) == (!p && !q))
SUITE["prop_logic"]["demorgan"] = begin
  quoted_expr = :(prove(propositional_logic_theory, ex_demorgan))
  @eval check_result($quoted_expr, true, "prop_logic/demorgan")
  @eval @benchmarkable $quoted_expr
end

ex_frege = :((p ⟹ (q ⟹ r)) ⟹ ((p ⟹ q) ⟹ (p ⟹ r)))
SUITE["prop_logic"]["freges_theorem"] = begin
  quoted_expr = :(prove(propositional_logic_theory, ex_frege))
  @eval check_result($quoted_expr, true, "prop_logic/freges_theorem")
  @eval @benchmarkable $quoted_expr
end

# ==================================================================

SUITE["calc_logic"] = BenchmarkGroup(["egraph", "logic"])

SUITE["calc_logic"]["demorgan"] = begin
  quoted_expr = :(prove(calculational_logic_theory, ex_demorgan))
  @eval check_result($quoted_expr, true, "calc_logic/demorgan")
  @eval @benchmarkable $quoted_expr
end

# TODO FIXME After https://github.com/JuliaSymbolics/Metatheory.jl/pull/261/ the order of application of
# matches in ematch_buffer has been reversed. There is likely some issue in rebuilding such that the
# order of application of rules changes the resulting e-graph, while this should not be the case.
# See comments in https://github.com/JuliaSymbolics/Metatheory.jl/pull/261#pullrequestreview-2609050078
SUITE["calc_logic"]["freges_theorem"] = begin
  quoted_expr = :(prove((reverse(calculational_logic_theory)), ex_frege, 2, 10))
  @eval check_result($quoted_expr, true, "calc_logic/freges_theorem")
  @eval @benchmarkable $quoted_expr
end

# ==================================================================

SUITE["while_superinterpreter"] = BenchmarkGroup(["egraph"])

exx = :((while x < 10
  x = x + 1
end;
x), $(Mem(:x => 3)))

function bench_while_superinterpreter(expr, expected)
  g = EGraph()
  id1 = addexpr!(g, expr)
  g.root = id1
  id2 = addexpr!(g, expected)
  goal = (g::EGraph) -> in_same_class(g, id1, id2)
  params = SaturationParams(timeout = 100, goal = goal, scheduler = Schedulers.SimpleScheduler)
  saturate!(g, while_language, params)
  extract!(g, astsize), g
end

SUITE["while_superinterpreter"]["while_10"] = begin
  expected = 10
  quoted_expr = :(bench_while_superinterpreter(exx, $expected))
  @eval check_result($quoted_expr, $expected, "while_superinterpreter/while_10")
  @eval @benchmarkable $quoted_expr
end

SUITE