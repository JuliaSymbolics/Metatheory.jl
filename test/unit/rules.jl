using Metatheory
using Test

_iseven(x) = x isa Integer && iseven(x)

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
  @test r == eval(:(@rule $(Meta.parse(repr(r)))))

  r = @rule Main.f(~~x) --> ~x
  @test r == eval(:(@rule $(Meta.parse(repr(r)))))
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

@testset "Theory-level predicates" begin
  # Type predicate on a theory slot: x::Number only matches numeric values
  t = @theory x::Number y begin
    x + y --> y + x
  end
  @test t[1](:(2 + a)) == :(a + 2)
  @test isnothing(t[1](:(a + b)))  # x=a is not a Number

  # Both slots predicated
  t2 = @theory x::Number y::Number begin
    x + y --> y + x
  end
  @test t2[1](:(1 + 2)) == :(2 + 1)
  @test isnothing(t2[1](:(a + 2)))  # x=a is not a Number
  @test isnothing(t2[1](:(1 + b)))  # y=b is not a Number

  # Function predicate (defined at module level so macro can resolve it)
  t3 = @theory x::_iseven y begin
    x + y --> y + x
  end
  @test t3[1](:(2 + a)) == :(a + 2)
  @test isnothing(t3[1](:(3 + a)))  # 3 is not even

  # Rule-level annotation overrides theory-level (more specific wins at the call site)
  t4 = @theory x::Number y begin
    x::Integer + y --> y + x
  end
  @test t4[1](:(2 + a)) == :(a + 2)
  @test isnothing(t4[1](:(1.5 + a)))  # 1.5 is Number but not Integer
end

