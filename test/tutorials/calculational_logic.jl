# # Rewriting Calculational Logic
using Metatheory, Test

include(joinpath(dirname(pathof(Metatheory)), "../examples/prove.jl"))
include(joinpath(dirname(pathof(Metatheory)), "../examples/calculational_logic_theory.jl"))


@testset "Calculational Logic" begin
  g = EGraph(:(((!p == p) == false)))
  saturate!(g, calculational_logic_theory)
  extract!(g, astsize)

  @test test_equality(calculational_logic_theory, :((!p || !p) == !p), :(!p || p), :(!(!p && p)))


  @test prove(calculational_logic_theory, :((!p == p) == false))
  @test prove(calculational_logic_theory, :((!p == !p) == true))
  @test prove(calculational_logic_theory, :((p ⟹ (p || p)) == true))

  params = SaturationParams(timeout = 12, eclasslimit = 10000, schedulerparams = (match_limit = 1000, ban_length = 5))
  @test prove(calculational_logic_theory, :(((p ⟹ (p || p)) == ((!(p) && q) ⟹ q))), 1, 10, params)

  freges = :((p ⟹ (q ⟹ r)) ⟹ ((p ⟹ q) ⟹ (p ⟹ r)))   # Frege's theorem
  params = SaturationParams(timeout = 12, eclasslimit = 10000)
  @test true == prove(calculational_logic_theory, freges, 2, 10, params)

  @test true == prove(calculational_logic_theory, :(!(p || q) == (!p && !q)))   # Demorgan's
end
