# https://en.wikipedia.org/wiki/MU_puzzle#Solution

using Metatheory

function ⋅ end
miu = @theory x y z begin
  # Composition of the string monoid is associative
  x ⋅ (y ⋅ z) --> (x ⋅ y) ⋅ z
  # Add a uf to the end of any string ending in I
  x ⋅ :I ⋅ :END --> x ⋅ :I ⋅ :U ⋅ :END
  # Double the string after the M
  :M ⋅ x ⋅ :END --> :M ⋅ x ⋅ x ⋅ :END
  # Replace any III with a U
  :I ⋅ :I ⋅ :I --> :U
  # Remove any UU
  x ⋅ :U ⋅ :U ⋅ y --> x ⋅ y
end


@testset "MU puzzle" begin
  # no matter the timeout we set here,
  # MU is not a theorem of the MIU system 
  params = SaturationParams(timeout = 12, eclasslimit = 8000)
  start = :(M ⋅ I ⋅ END)
  g = EGraph(start)
  saturate!(g, miu)
  @test false == areequal(g, miu, start, :(M ⋅ U ⋅ END); params = params)
end
