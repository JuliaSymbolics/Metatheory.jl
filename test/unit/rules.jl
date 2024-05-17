using Metatheory, Test

@testset begin
  r = @rule f(~x) --> ~x

  @test isempty(r.name)

  r = @rule "totti" f(~x) --> ~x
  @test r.name == "totti"
  @test operation(r.left) == :f
  @test arguments(r.left) == [PatVar(:x, 1)]
  @test r.right == PatVar(:x, 1)
end