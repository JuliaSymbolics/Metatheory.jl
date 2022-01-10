using BenchmarkTools
using Metatheory


SUITE = BenchmarkGroup()

egraph = SUITE["egraph"] = BenchmarkGroup()

# E-Graph creation
egraph["creation"] = BenchmarkGroup()
egraph["creation"]["empty"] = @benchmarkable EGraph()
egraph["creation"]["expr"] = @benchmarkable EGraph(:(a + b^2 / (x^2 - 123 + Dict(:x => 2))))
