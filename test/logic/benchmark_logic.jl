include("prop_logic_theory.jl")
include("prover.jl")

using Test

Metatheory.options.verbose = true

ex = rewrite(:(((p => q) ∧ (r => s) ∧ (p ∨ r)) => (q ∨ s)), impl)
@profview prove(t, ex, 2, 7)
