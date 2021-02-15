# https://en.wikipedia.org/wiki/MU_puzzle#Solution
#

miu = @theory begin
    # Composition of the string monoid is associative
    x ⋅ (y ⋅ z) => (x ⋅ y) ⋅ z
    # Add a U to the end of any string ending in I
    x ⋅ :I =>  x ⋅ :I ⋅ :U
    # Double the string after the M
    :M ⋅ x  => :M ⋅ x ⋅ x
    # Replace any III with a U
    x ⋅ :I ⋅ :I ⋅ :I ⋅ y => x ⋅ :U ⋅ y
    # Remove any UU
    x ⋅ :U ⋅ :U ⋅ y => x ⋅ y
end


@testset "MU puzzle" begin
    # no matter the timeout we set here,
    # MU is not a theorem of the MIU system
    @test false == areequal(miu, :(M⋅U), :(M⋅I), timeout=12, sizeout=2^13)
end
