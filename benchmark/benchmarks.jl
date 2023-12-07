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


include("maths_theory.jl")
include("logic_theory.jl")


SUITE["maths"] = BenchmarkGroup(["egraphs"])

ex = :(a + b + (0 * c) + d)
SUITE["maths"]["simpl1"] = @benchmarkable simplify($ex, $maths_theory, $(SaturationParams()), postprocess_maths)

# ==================================================================

SUITE["logic"] = BenchmarkGroup(["egraph", "logic"])

ex_orig = :(((p ⟹ q) && (r ⟹ s) && (p || r)) ⟹ (q || s))
ex = rewrite(ex_orig, impl)

SUITE["logic"]["rewrite"] = @benchmarkable rewrite($ex_orig, $impl)
SUITE["logic"]["prove1"] = @benchmarkable prove($maths_theory, $ex, 5, 10, 5000)

