using Metatheory

comm_monoid = @theory begin
    a * b => b * a
    a * 1 => a
    a * (b * c) => (a * b) * c
    a::Number * b::Number |> a*b
end

G = EGraph(:(3 * 4))
@testset "Basic Constant Folding Example - Commutative Monoid" begin
    @test (true == @areequalg G comm_monoid 3 * 4 12)
    @test (true == @areequalg G comm_monoid 3 * 4 12 4*3  6*2)
end


@testset "Basic Constant Folding Example 2 - Commutative Monoid" begin
    ex = :(a * 3 * b * 4)
    G = EGraph(ex)
    @test (true == @areequalg G comm_monoid (3 * a) * (4 * b) (12*a)*b ((6*2)*b)*a)
end
