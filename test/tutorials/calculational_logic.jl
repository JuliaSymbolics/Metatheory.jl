# # Rewriting Calculational Logic
using Metatheory, Test

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

  @test areequal(calculational_logic_theory, true, :(((p ⟹ (p || p)) == ((!(p) && q) ⟹ q))); params = params)

  ex = :((p ⟹ (q ⟹ r)) ⟹ ((p ⟹ q) ⟹ (p ⟹ r)))   # Frege's theorem
  res = areequal(calculational_logic_theory, true, ex; params = params)
  @test_broken !ismissing(res) && res


  @test @areequal calculational_logic_theory true (!(p || q) == (!p && !q))   # Demorgan's

  areequal(calculational_logic_theory, :((x && y) || (!x && z) || (y && z)), :((x && y) || (!x && z)); params = params)   # Consensus theorem
end
