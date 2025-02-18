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
  expr, g = simplify(
    simpl1_math,
    maths_theory,
    SaturationParams(; timer = false),
    postprocess_maths,
  )
  report_size("basic_maths_simpl1", g)
  @assert :(a + b + d) == expr

  @benchmarkable simplify($simpl1_math, $maths_theory, $(SaturationParams(; timer = false)), postprocess_maths)
end

simpl2_math = :(0 + (1 * foo) * 0 + (a * 0) + a)
SUITE["basic_maths"]["simpl2"] = begin
  expr,g = simplify(simpl2_math, maths_theory, (SaturationParams()), postprocess_maths)
  report_size("basic_maths_simpl2", g)
  @assert :a == expr
  @benchmarkable simplify($simpl2_math, $maths_theory, $(SaturationParams()), postprocess_maths)
end

# ==================================================================

SUITE["prop_logic"] = BenchmarkGroup(["egraph", "logic"])

ex_orig = :(((p ⟹ q) && (r ⟹ s) && (p || r)) ⟹ (q || s))
ex_logic = rewrite(ex_orig, impl)

SUITE["prop_logic"]["rewrite"] = @benchmarkable rewrite($ex_orig, $impl)

SUITE["prop_logic"]["prove1"] = begin 
  expr,g = prove(propositional_logic_theory, ex_logic, 3, 6)
  report_size("prop_logic_prove1", g)
  @assert expr == true
  @benchmarkable prove($propositional_logic_theory, $ex_logic, 3, 6)
end

ex_demorgan = :(!(p || q) == (!p && !q))
SUITE["prop_logic"]["demorgan"] = begin
  expr,g = prove(propositional_logic_theory, ex_demorgan)
  report_size("prop_logic_demorgan", g)
  @assert expr == true
  @benchmarkable prove($propositional_logic_theory, $ex_demorgan)
end

ex_frege = :((p ⟹ (q ⟹ r)) ⟹ ((p ⟹ q) ⟹ (p ⟹ r)))
SUITE["prop_logic"]["freges_theorem"] = begin
  expr,g = prove(propositional_logic_theory, ex_frege)
  report_size("prop_logic_freges_theorem", g)
  @assert expr == true
  @benchmarkable prove($propositional_logic_theory, $ex_frege)
end

# ==================================================================

SUITE["calc_logic"] = BenchmarkGroup(["egraph", "logic"])

SUITE["calc_logic"]["demorgan"] = begin
  expr,g = prove(calculational_logic_theory, ex_demorgan)
  report_size("calc_logic_demorgan", g)
  @assert expr == true
  @benchmarkable prove($calculational_logic_theory, $ex_demorgan)
end

# TODO FIXME After https://github.com/JuliaSymbolics/Metatheory.jl/pull/261/ the order of application of
# matches in ematch_buffer has been reversed. There is likely some issue in rebuilding such that the
# order of application of rules changes the resulting e-graph, while this should not be the case.
# See comments in https://github.com/JuliaSymbolics/Metatheory.jl/pull/261#pullrequestreview-2609050078
SUITE["calc_logic"]["freges_theorem"] = begin
  expr,g = prove((reverse(calculational_logic_theory)), ex_frege, 2, 10)
  report_size("calc_logic_freges_theorem", g)
  @assert expr == true
  @benchmarkable prove($(reverse(calculational_logic_theory)), $ex_frege, 2, 10)
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
  expr,g = bench_while_superinterpreter(exx, expected)
  report_size("while_superinterpreter_while_10", g)
  @assert expr == expected
  @benchmarkable bench_while_superinterpreter($exx, $expected)
end

SUITE