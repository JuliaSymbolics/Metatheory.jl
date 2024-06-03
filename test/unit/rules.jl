using Metatheory, Test

@testset "Fully Qualified Function name" begin
  r = @rule Main.identity(~a) --> ~a

  @test operation(r.left) == identity
  @test r.right == PatVar(:a, 1)
end

@testset begin
  r = @rule f(~x) --> ~x

  @test isempty(r.name)

  r = @rule "totti" f(~x) --> ~x
  @test r.name == "totti"
  @test operation(r.left) == :f
  @test arguments(r.left) == [PatVar(:x, 1)]
  @test r.right == PatVar(:x, 1)
end