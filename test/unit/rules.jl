using Metatheory, Test

@testset "Fully Qualified Function names" begin
  r = @rule Main.identity(~a) --> ~a

  @test operation(r.left) == identity
  @test r.right == PatVar(:a, 1)

  expr = :(Main.test(11, 12))
  rule = @rule Main.test(~a, ~b) --> ~b
  @test rule(expr) == 12
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


@testset "String representation" begin
  r = @rule f(~x) --> ~x
  r == eval(:(@rule $(Meta.parse(repr(r)))))

  r = @rule Main.f(~~x) --> ~x
  r == eval(:(@rule $(Meta.parse(repr(r)))))
end


#@testset "EqualityRule to DirectedRule(s)" begin
  r = @rule "distributive" x y z x*(y + z) == x*y + x*z
  r1 = direct(r)
  r2 = Metatheory.direct_right_to_left(r)

  @test r1 isa DirectedRule
  @test r2 isa DirectedRule
  @test r1 == @rule "distributive" x y z x * (y + z) --> x*y + x*z
  @test r2 == @rule "distributive" x y z x*y + x*z --> x * (y + z)
#end

