
using Test

include("logic.jl")

# ex = rewrite(:(((p => q) ∧ (r => s) ∧ (p ∨ r)) => (q ∨ s)), impl)
ex = :(((p => q) ∧ (r => s) ∧ (p ∨ r)) => (q ∨ s))
@test prove(prop_logic_theory, ex, 2, 7)


@test @areequal prop_logic_theory true ((¬p == p) == false)
@test @areequal prop_logic_theory true ((¬p == ¬p) == true)
@test @areequal prop_logic_theory true ((¬p ∨ ¬p) == ¬p) (¬p ∨ p) ¬(¬p ∧ p)
@test @areequal prop_logic_theory true ((p => (p ∨ p)))
@test @areequal prop_logic_theory true ((p => (p ∨ p)) == ((¬(p) ∧ q) => q)) == true

# Frege's theorem
@test @areequal prop_logic_theory true (p => (q => r)) => ((p => q) => (p => r))

# Demorgan's
@test @areequal prop_logic_theory true (¬(p ∨ q) == (¬p ∧ ¬q))

# Consensus theorem
@test @areequal prop_logic_theory ((x ∧ y) ∨ (¬x ∧ z) ∨ (y ∧ z))   ((x ∧ y) ∨ (¬x ∧ z))


# Calculational logic

@test @areequal calc_logic_theory true ((¬p == p) == false)
@test @areequal calc_logic_theory true ((¬p == ¬p) == true)
@test @areequal calc_logic_theory true ((¬p ∨ ¬p) == ¬p) (¬p ∨ p) ¬(¬p ∧ p)
@test @areequal calc_logic_theory true ((p => (p ∨ p)) == true)
params = SaturationParams(timeout=12, eclasslimit=10000, schedulerparams=(1000, 5))

@test areequal(calc_logic_theory, true, :(((p => (p ∨ p)) == ((¬(p) ∧ q) => q)) == true); params=params)

# Frege's theorem
# params = SaturationParams(timeout=12, eclasslimit=15000, scheduler=Schedulers.ScoredScheduler)
# params = SaturationParams(timeout=12, eclasslimit=15000, schedulerparams=(500, 2))
@test_skip areequal(calc_logic_theory, true, :((p => (q => r)) => ((p => q) => (p => r))); params=params)

# Demorgan's
@test @areequal calc_logic_theory true (¬(p ∨ q) == (¬p ∧ ¬q))

# Consensus theorem
# @test_skip
areequal(calc_logic_theory, :((x ∧ y) ∨ (¬x ∧ z) ∨ (y ∧ z)), :((x ∧ y) ∨ (¬x ∧ z)); params=params)

