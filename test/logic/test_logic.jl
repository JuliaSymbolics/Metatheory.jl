include("prop_logic_theory.jl")
include("prover.jl")

using Test

ex = rewrite(:(((p => q) ∧ (r => s) ∧ (p ∨ r)) => (q ∨ s)), impl)
@test prove(t, ex, 3, 10, 5000)


@test @areequal t true ((¬p == p) == false)
@test @areequal t true ((¬p == ¬p) == true)
@test @areequal t true ((¬p ∨ ¬p) == ¬p) (¬p ∨ p) ¬(¬p ∧ p)
@test @areequal t true ((p => (p ∨ p)))
@test @areequal t true ((p => (p ∨ p)) == ((¬(p) ∧ q) => q)) == true

# Frege's theorem
@test @areequal t true (p => (q => r)) => ((p => q) => (p => r))

# Demorgan's
@test @areequal t true (¬(p ∨ q) == (¬p ∧ ¬q))

# Consensus theorem
@test @areequal t ((x ∧ y) ∨ (¬x ∧ z) ∨ (y ∧ z))   ((x ∧ y) ∨ (¬x ∧ z))

