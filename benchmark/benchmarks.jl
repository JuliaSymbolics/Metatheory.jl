using BenchmarkTools
using Metatheory

pkgpath = dirname(dirname(pathof(Metatheory)))

SUITE = BenchmarkGroup()

egraph = SUITE["egraph"] = BenchmarkGroup()

# E-Graph creation
egraph["creation"] = BenchmarkGroup()
egraph["creation"]["empty"] = @benchmarkable EGraph()
egraph["creation"]["expr"] = @benchmarkable EGraph(:(a + b^2 / (x^2 - 123 + Dict(:x => 2))))

egraph["full_examples"] = BenchmarkGroup()

# Logic Example
include(joinpath(pkgpath, "test", "logic", "prop_logic_theory.jl"))

ex = rewrite(:(((p => q) ∧ (r => s) ∧ (p ∨ r)) => (q ∨ s)), impl)

egraph["full_examples"]["logic"] = @benchmarkable prove(t, ex, 2, 7)

