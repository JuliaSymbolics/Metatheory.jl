include("prop_logic_theory.jl")
include("prover.jl")

Metatheory.options.verbose = true

ex = rewrite(:(((p => q) ∧ (r => s) ∧ (p ∨ r)) => (q ∨ s)), impl)
prove(t, ex, 2, 7)
@profview prove(t, ex, 2, 7)

