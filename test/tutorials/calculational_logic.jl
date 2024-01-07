# # Rewriting Calculational Logic
using Metatheory

include(joinpath(dirname(pathof(Metatheory)), "../examples/calculational_logic_theory.jl"))


@testset "Calculational Logic" begin
  g = EGraph(:(((!p == p) == false)))
  saturate!(g, calculational_logic_theory)
  extract!(g, astsize)

  @test @areequal calculational_logic_theory true ((!p == p) == false)
  @test @areequal calculational_logic_theory true ((!p == !p) == true)
  @test @areequal calculational_logic_theory true ((!p || !p) == !p) (!p || p) !(!p && p)
  @test @areequal calculational_logic_theory true ((p ⟹ (p || p)) == true)
  params = SaturationParams(timeout = 12, eclasslimit = 10000, schedulerparams = (1000, 5))

  @test areequal(calculational_logic_theory, true, :(((p ⟹ (p || p)) == ((!(p) && q) ⟹ q)) == true); params = params)

  # Frege's theorem
  @test areequal(calculational_logic_theory, true, :((p ⟹ (q ⟹ r)) ⟹ ((p ⟹ q) ⟹ (p ⟹ r))); params = params)

  # Demorgan's
  @test @areequal calculational_logic_theory true (!(p || q) == (!p && !q))

  # Consensus theorem
  areequal(calculational_logic_theory, :((x && y) || (!x && z) || (y && z)), :((x && y) || (!x && z)); params = params)
end
