# Proving Propositional Logic Statements

using Test
using Metatheory
using TermInterface

include(joinpath(dirname(pathof(Metatheory)), "../examples/propositional_logic_theory.jl"))

@testset "Prop logic" begin
  ex = rewrite(:(((p ⟹ q) && (r ⟹ s) && (p || r)) ⟹ (q || s)), impl)
  # Match pre-6f39e4b prove(..., steps, timeout, eclasslimit) via SaturationParams
  params = SaturationParams(
    timeout = 10,
    eclasslimit = 5000,
    scheduler = Schedulers.BackoffScheduler,
    schedulerparams = (6000, 5),
    timer = false,
  )
  @test prove(propositional_logic_theory, ex, 5, 10, params)


  @test @areequal propositional_logic_theory true ((!p == p) == false)
  @test @areequal propositional_logic_theory true ((!p == !p) == true)
  @test @areequal propositional_logic_theory true ((!p || !p) == !p) (!p || p) !(!p && p)
  @test @areequal propositional_logic_theory p (p || p)
  @test @areequal propositional_logic_theory true ((p ⟹ (p || p)))
  @test @areequal propositional_logic_theory true ((p ⟹ (p || p)) == ((!(p) && q) ⟹ q)) == true

  # Frege's theorem
  @test @areequal propositional_logic_theory true (p ⟹ (q ⟹ r)) ⟹ ((p ⟹ q) ⟹ (p ⟹ r))

  # Demorgan's
  @test @areequal propositional_logic_theory true (!(p || q) == (!p && !q))

  # Consensus theorem
  # @test_broken @areequal propositional_logic_theory true ((x && y) || (!x && z) || (y && z)) ((x && y) || (!x && z))
end
