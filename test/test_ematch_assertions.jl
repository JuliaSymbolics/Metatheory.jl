using Metatheory

@testset "Type Assertions in Ematcher" begin
    some_theory = @theory begin
        ~a * ~b --> ~b * ~a
        ~a::Number * ~b::Number --> matched(~a,~b)
        ~a::Int64 * ~b::Int64 --> specific(~a,~b)
        ~a * (~b * ~c) --> (~a * ~b) * ~c
    end

    g = EGraph(:(2*3))
    saturate!(g, some_theory)
    # display(g.classes)

    @test true == areequal(g, some_theory, :(2 * 3), :(matched(2,3)))
    @test true == areequal(g, some_theory, :(matched(2,3)), :(specific(3,2)))
end
