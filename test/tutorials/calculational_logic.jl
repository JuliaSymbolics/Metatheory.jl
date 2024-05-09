# # Rewriting Calculational Logic
using Metatheory, Test

include(joinpath(dirname(pathof(Metatheory)), "../examples/prove.jl"))
include(joinpath(dirname(pathof(Metatheory)), "../examples/calculational_logic_theory.jl"))


@testset "Calculational Logic" begin
  g = EGraph(:(((!p == p) == false)))
  saturate!(g, calculational_logic_theory)
  extract!(g, astsize)

  @test @areequal calculational_logic_theory ((!p == p) == false) true
  @test @areequal calculational_logic_theory ((!p == !p) == true) true
  @test @areequal calculational_logic_theory ((!p || !p) == !p) (!p || p) !(!p && p) true
  @test @areequal calculational_logic_theory ((p ⟹ (p || p)) == true) true

  params = SaturationParams(timeout = 12, eclasslimit = 10000, schedulerparams = (1000, 5))
  @test areequal(calculational_logic_theory, :(((p ⟹ (p || p)) == ((!(p) && q) ⟹ q))), true; params = params)

  ex = :((p ⟹ (q ⟹ r)) ⟹ ((p ⟹ q) ⟹ (p ⟹ r)))   # Frege's theorem
  params = SaturationParams(timeout = 12, eclasslimit = 10000, schedulerparams = (6000, 5))
  @test prove(calculational_logic_theory, ex, 2, 10, params)

  @test @areequal calculational_logic_theory (!(p || q) == (!p && !q)) true   # Demorgan's

  @test_broken prove(
    calculational_logic_theory,
    :(((x && y) || (!x && z) || (y && z)) == ((x && y) || (!x && z))),
    2,
    10,
    params,
  )  # Consensus theorem
end
