using BenchmarkTools
using Metatheory
using Metatheory.Library

const SUITE = BenchmarkGroup()

function simplify(ex, theory, params = SaturationParams(), postprocess = identity)
  g = EGraph(ex)
  report = saturate!(g, theory, params)
  println(report)
  res = extract!(g, astsize)
  postprocess(res)
end


include(joinpath(dirname(pathof(Metatheory)), "../examples/basic_maths_theory.jl"))
include(joinpath(dirname(pathof(Metatheory)), "../examples/propositional_logic_theory.jl"))
include(joinpath(dirname(pathof(Metatheory)), "../examples/calculational_logic_theory.jl"))


SUITE["basic_maths"] = BenchmarkGroup(["egraphs"])

ex_math = :(a + b + (0 * c) + d)
SUITE["basic_maths"]["simpl1"] =
  @benchmarkable (@assert :(a + b + d) == simplify($ex_math, $maths_theory, $(SaturationParams()), postprocess_maths))

# ==================================================================

SUITE["prop_logic"] = BenchmarkGroup(["egraph", "logic"])

ex_orig = :(((p ⟹ q) && (r ⟹ s) && (p || r)) ⟹ (q || s))
ex_logic = rewrite(ex_orig, impl)

SUITE["prop_logic"]["rewrite"] = @benchmarkable rewrite($ex_orig, $impl)
SUITE["prop_logic"]["prove1"] = @benchmarkable (@assert prove($propositional_logic_theory, $ex_logic, 3, 5, 5000))

ex_demorgan = :(!(p || q) == (!p && !q))
SUITE["prop_logic"]["demorgan"] = @benchmarkable (@assert prove($propositional_logic_theory, $ex_demorgan))

ex_frege = :((p ⟹ (q ⟹ r)) ⟹ ((p ⟹ q) ⟹ (p ⟹ r)))
SUITE["prop_logic"]["freges_theorem"] = @benchmarkable (@assert prove($propositional_logic_theory, $ex_frege))

# ==================================================================

SUITE["calc_logic"] = BenchmarkGroup(["egraph", "logic"])

SUITE["calc_logic"]["demorgan"] = @benchmarkable (@assert prove($calculational_logic_theory, $ex_demorgan))
SUITE["calc_logic"]["freges_theorem"] =
  @benchmarkable (@assert prove($calculational_logic_theory, $ex_frege, 1, 10, 10000))
