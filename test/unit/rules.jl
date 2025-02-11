using Metatheory, Test

@testset "Fully Qualified Function names" begin
  r = @rule Main.identity(~a) --> ~a

  @test operation(r.left) == identity
  @test r.right == pat_var(PAT_VARIABLE, :a, 1)

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
  @test arguments(r.left) == [pat_var(PAT_VARIABLE, :x, 1)]
  @test r.right == pat_var(PAT_VARIABLE, :x, 1)
end


@testset "String representation" begin
  r = @rule f(~x) --> ~x
  r == eval(:(@rule $(Meta.parse(repr(r)))))

  r = @rule Main.f(~~x) --> ~x
  r == eval(:(@rule $(Meta.parse(repr(r)))))
end


@testset "EqualityRule to DirectedRule(s)" begin
  r = @rule "distributive" x y z x * (y + z) == x * y + x * z
  r_ltr = @rule "distributive" x y z x * (y + z) --> x * y + x * z
  r_rtl = @rule "distributive" x y z x * y + x * z --> x * (y + z)
  r1 = direct(r)
  r2 = Metatheory.direct_right_to_left(r)

  @test r1 isa DirectedRule
  @test r2 isa DirectedRule
  @test repr(r1) == repr(r_ltr)
  @test repr(r2) == repr(r_rtl)
end

