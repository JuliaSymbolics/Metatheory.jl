@testset "Type Assertions in Ematcher" begin
    some_theory = @theory begin
        a * b => b * a
        a::$Number * b::$Number => matched(a,b)
        a::$Int64 * b::$Int64 => specific(a,b)
        a * (b * c) => (a * b) * c
    end

    G = EGraph(:(2*3))
    

    @test true == areequal(G, some_theory, :(2 * 3), :(matched(2,3)))
    @test true == areequal(G, some_theory, :(matched(2,3)), :(specific(3,2)))
end

# TODO removed by now! Text Taine Zhao
# @testset "Type Variables in Ematcher" begin
#     some_theory = @theory begin
#         a * b => b * a
#         a::T * b::T => sametype(T)
#         a * (b * c) => (a * b) * c
#     end
#
#     G = EGraph(:(2*3))
#     display(G.M); println()
#     res = areequal(G, some_theory, :(2 * 3), :(sametype($Int64)))
#     display(G.M); println()
#     @test res
#
#     G = EGraph(:(2*"ciao"))
#     display(G.M); println()
#     res = !areequal(G, some_theory, :(2 * "ciao"), :(sametype($Int64)))
#     display(G.M); println()
#     @test res
#
#     G = EGraph(:("ciaoz"*"ciao"))
#     display(G.M); println()
#     res = areequal(G, some_theory, :("ciaoz" * "ciao"), :(sametype($String)))
#     display(G.M); println()
#     @test res
#     # @test true == areequal(G, some_theory, :(matched(2,3)), :(specific(3,2)))
# end
