using BenchmarkTools
using Metatheory
using Metatheory.Library

const SUITE = BenchmarkGroup()

function simplify(ex, theory, params = SaturationParams(), postprocess = identity)
  g = EGraph(ex)
  report = saturate!(g, cas, params)
  println(report)
  res = extract!(g, astsize)
  postprocess(res)
end


include("maths_theory.jl")

SUITE["maths"] = BenchmarkGroup(["egraphs"])

ex1 = :(a + b + (0 * c) + d)
SUITE["maths"]["simpl1"] = @benchmarkable simplify($ex1, $maths_theory, $(SaturationParams()), postprocess_maths)
