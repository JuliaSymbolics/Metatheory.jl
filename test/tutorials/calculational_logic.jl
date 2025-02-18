# # Rewriting Calculational Logic
using Metatheory, Test

include(joinpath(dirname(pathof(Metatheory)), "../examples/prove.jl"))
include(joinpath(dirname(pathof(Metatheory)), "../examples/calculational_logic_theory.jl"))


@testset "Calculational Logic" begin
  g = EGraph(:(((!p == p) == false)))
  saturate!(g, calculational_logic_theory)
  extract!(g, astsize)

  @test test_equality(calculational_logic_theory, :((!p || !p) == !p), :(!p || p), :(!(!p && p)))


  @test true == prove(calculational_logic_theory, :((!p == p) == false))[1]
  @test true == prove(calculational_logic_theory, :((!p == !p) == true))[1]
  @test true == prove(calculational_logic_theory, :((p ⟹ (p || p)) == true))[1]

  params = SaturationParams(timeout = 12, eclasslimit = 10000, schedulerparams = (match_limit = 1000, ban_length = 5))
  @test true == prove(calculational_logic_theory, :(((p ⟹ (p || p)) == ((!(p) && q) ⟹ q))), 1, 10, params)[1]

  freges = :((p ⟹ (q ⟹ r)) ⟹ ((p ⟹ q) ⟹ (p ⟹ r)))   # Frege's theorem
  params = SaturationParams(timeout = 12, eclasslimit = 10000, schedulerparams = (match_limit = 6000, ban_length = 5))
  # TODO FIXME After https://github.com/JuliaSymbolics/Metatheory.jl/pull/261/ the order of application of
  # matches in ematch_buffer has been reversed. There is likely some issue in rebuilding such that the
  # order of application of rules changes the resulting e-graph, while this should not be the case.
  # See comments in https://github.com/JuliaSymbolics/Metatheory.jl/pull/261#pullrequestreview-2609050078
  @test true == prove(reverse(calculational_logic_theory), freges, 2, 10, params)[1]

  @test true == prove(calculational_logic_theory, :(!(p || q) == (!p && !q)))[1]   # Demorgan's
end
