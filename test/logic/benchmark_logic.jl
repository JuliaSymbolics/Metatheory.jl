include("prop_logic_theory.jl")
include("prover.jl")

ex = rewrite(:(((p => q) ∧ (r => s) ∧ (p ∨ r)) => (q ∨ s)), impl)
prove(t, ex, 1, 25)
@profview prove(t, ex, 2, 7)

