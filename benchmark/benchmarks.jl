using BenchmarkTools
using Metatheory


SUITE = BenchmarkGroup()

egraph = SUITE["egraph"] = BenchmarkGroup()
egraph["creation"] = @benchmarkable EGraph()
