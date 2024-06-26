using Metatheory, TermInterface
using Test

@testset "Reduction Basics" begin
  t = @theory begin
    ~a + ~a --> 2 * (~a)
    ~x / ~x --> 1
    ~x * 1 --> ~x
  end

  # basic theory to check that everything works
  @test rewrite(:(a + a), t) == :(2a)
  @test rewrite(:(a + (x * 1)), t) == :(a + x)
  @test rewrite(:(a + (a * 1)), t; order = :inner) == :(2a)
end


## Free Monoid

@testset "Free Monoid - Overriding identity" begin
  # support symbol literals
  function ⋅ end
  symbol_monoid = @theory begin
    ~a ⋅ :ε --> ~a
    :ε ⋅ ~a --> ~a
    ~a::Symbol --> ~a
    ~a::Symbol ⋅ ~b::Symbol => Symbol(String(a) * String(b))
    # i |> error("unsupported ", i)
  end

  @test rewrite(:(ε ⋅ a ⋅ ε ⋅ b ⋅ c ⋅ (ε ⋅ ε ⋅ d) ⋅ e), symbol_monoid; order = :inner) == :abcde
end

## Interpolation should be possible at runtime


@testset "Calculator" begin
  function ⊗ end
  function ⊕ end
  function ⊖ end
  calculator = @theory begin
    ~x::Number ⊕ ~y::Number => ~x + ~y
    ~x::Number ⊗ ~y::Number => ~x * ~y
    ~x::Number ⊖ ~y::Number => ~x ÷ ~y
    ~x::Symbol --> ~x
    ~x::Number --> ~x
  end
  a = 10

  @test rewrite(:(3 ⊕ 1 ⊕ $a), calculator; order = :inner) == 14
end


## Direct rules
@testset "Direct Rules" begin
  t = @theory begin
    # maps
    ~a * ~b => ((~a isa Number && ~b isa Number) ? ~a * ~b : _lhs_expr)
  end
  @test rewrite(:(3 * 1), t) == 3

  t = @theory begin
    # maps
    ~a::Number * ~b::Number => ~a * ~b
  end
  @test rewrite(:(3 * 1), t) == 3
end



## Take advantage of subtyping.
# Subtyping in Julia has been formalized in this paper
# [Julia Subtyping: A Rational Reconstruction](https://benchung.github.io/papers/jlsub.pdf)

abstract type Vehicle end
abstract type GroundVehicle <: Vehicle end
abstract type AirVehicle <: Vehicle end
struct Airplane <: AirVehicle end
struct Car <: GroundVehicle end

airpl = Airplane()
car = Car()

t = @theory begin
  ~a::AirVehicle * ~b => "flies"
  ~a::GroundVehicle * ~b => "doesnt_fly"
end

@testset "Subtyping" begin

  sf = rewrite(:($airpl * c), t)
  df = rewrite(:($car * c), t)

  @test sf == "flies"
  @test df == "doesnt_fly"
end


@testset "Interpolation" begin
  airpl = Airplane()
  car = Car()
  t = @theory begin
    airpl * ~b => "flies"
    car * ~b => "doesnt_fly"
  end

  sf = rewrite(:($airpl * c), t)
  df = rewrite(:($car * c), t)

  @test sf == "flies"
  @test df == "doesnt_fly"
end

@testset "New compiled pattern matcher" begin
  r = @rule f(1, 2) --> ok()
  @test isnothing(r(:(f(1, 2, 3))))
  @test r(:(f(1, 2))) == :(ok())
end

@testset "PatSegment as tail" begin
  r = @rule f(~x, ~~y) => Expr(:call, :ok, (~~y)...)
  sf = r(:(f(1, 2, 3, 4)))
  @test sf == :(ok(2, 3, 4))

  r = @rule x y f(x, 2, y...) => Expr(:call, :ok, y...)
  sf = r(:(f(1, 2, 3, 4)))
  @test sf == :(ok(3, 4))

  sf = r(:(f(1, 2, 3)))
  @test sf == :(ok(3))

  # Empty vector
  r = @rule x y f(x, 2, 3, 4, y...) --> ok(y...)
  sf = r(:(f(1, 2, 3, 4)))
  @test sf == :(ok())

  # Entire vector
  r = @rule x f(x...) --> ok(x...)
  sf = r(:(f(1, 2, 3, 4)))
  @test sf == :(ok(1, 2, 3, 4))

  # Nested inside
  r = @rule x y g(1, f(x, 2, y...), 3) => Expr(:call, :ok, x, y...)
  sf = r(:(g(1, f(1, 2, 3, 4), 3)))
  @test sf == :(ok(1, 3, 4))

  sf = r(:(g(1, f(1, 2, 3), 3)))
  @test sf == :(ok(1, 3))

  sf = r(:(g(1, f(1, 2, 3, h(4, 5), 6), 3)))
  @test sf == :(ok(1, 3, h(4, 5), 6))
end

@testset "PatSegment as head" begin
  r = @rule f(~~x, ~y) => Expr(:call, :ok, (~~x)...)
  sf = r(:(f(1, 2, 3, 4)))
  @test sf == :(ok(1, 2, 3))

  r = @rule x y f(x..., 3, 4) => Expr(:call, :ok, x...)
  sf = r(:(f(1, 2, 3, 4)))
  @test sf == :(ok(1, 2))

  # Single element
  r = @rule x y f(x, 2, 3, y...) --> ok(y...)
  sf = r(:(f(1, 2, 3, 4)))
  @test sf == :(ok(4))

  # Empty vector
  r = @rule x y f(x, 2, 3, 4, y...) --> ok(y...)
  sf = r(:(f(1, 2, 3, 4)))
  @test sf == :(ok())
end

@testset "Multiple PatSegments" begin
  r = @rule f(~~x, ~~y) --> ok(~~x, yeah(~~y))
  sf = r(:(f(1, 2, 3, 4)))
  @test sf == :(ok(1, 2, 3, 4, yeah()))

  r = @rule f(~~x, 3, ~~y) --> ok(~~x, yeah(~~y))
  sf = r(:(f(1, 2, 3, 4, 5)))
  @test sf == :(ok(1, 2, yeah(4, 5)))

  r = @rule f(~~x, 3, ~~y, 5, ~~z) --> ok(~~x, yeah(~~y), ~~z)
  sf = r(:(f(1, 2, 3, 4, 5, 6)))
  @test sf == :(ok(1, 2, yeah(4), 6))

  r = @rule f(~~x, 3, ~~y, 5, ~~z, 7) --> ok(~~x, yeah(~~y), ~~z)
  sf = r(:(f(1, 2, 2, 3, 4, 4, 5, 6, 7, 7)))
  @test sf == :(ok(1, 2, 2, yeah(4, 4), 6, 7))
end

@testset "Multiple Repeated PatSegments" begin
  r = @rule f(~~x, ~~x, 4) --> ok(~~x)
  sf = r(:(f(1, 2, 1, 2, 4)))
  @test sf == :(ok(1, 2))

  sf = r(:(f(1, 2, 3, 4)))
  @test isnothing(sf)

  sf = r(:(f(4)))
  @test sf == :(ok())


  r = @rule f(~~x, ~~x) --> ok(~~x)
  sf = r(:(f(1, 2, 1, 2)))
  @test sf == :(ok(1, 2))

  sf = r(:(f(1, 2, 3, 4)))
  @test isnothing(sf)

  r = @rule f(~~x, 3, ~~x) --> ok(~~x)
  sf = r(:(f(1, 2, 3, 1, 2)))
  @test sf == :(ok(1, 2))

  r = @rule f(~~x, 3, ~~x) --> ok(~~x)
  sf = r(:(f(3)))
  @test sf == :(ok())

  sf = r(:(f(1, 2, 3, 4, 5)))
  @test isnothing(sf)

  # Appears 3 times, doesn't work because of `offset_so_far` not counting how many times 
  # a variable appears
  r = @rule f(~~x, 3, ~~x, 5, ~~x) --> ok(~~x)
  sf = r(:(f(1, 2, 3, 1, 2, 5, 1, 2)))
  @test sf == :(ok(1, 2))

  sf = r(:(f(1, 2, 3, 3, 1, 2, 5, 1, 2)))
  @test isnothing(sf)


  r = @rule f(~~x, 3, ~~y, 5, ~~x, ~~z, 7, ~~y) --> ok(~~x, yeah(~~y), ~~z)
  sf = r(:(f(1, 2, 2, 3, 4, 4, 5, 1, 2, 2, 6, 7, 7, 4, 4)))
  @test sf == :(ok(1, 2, 2, yeah(4, 4), 6, 7))
end

module NonCall
using Metatheory, TermInterface
t = [@rule a b (a, b) --> ok(a, b)]

test() = rewrite(:(x, y), t)
end

@testset "Non-Call expressions" begin
  @test NonCall.test() == :(ok(x, y))
end


@testset "Pattern matcher can match on both function object references and name symbols" begin
  r = @rule(sin(~x)^2 + cos(~x)^2 --> 1)
  ex = :($(+)($(sin)(x)^2, $(cos)(x)^2))

  @test r(ex) == 1
end


@testset "Pattern variable as pattern term head" begin
  foo(x) = x + 2
  ex = :(($foo)(bar, 2, pazz))
  r = @rule ((~f)(~x, 2, ~y) => (~f)(2))

  @test r(ex) == 4
end


using Metatheory.Syntax: @capture
@testset "Capture form" begin
  ex = :(a^a)

  #note that @test inserts a soft local scope (try-catch) that would gobble
  #the matches from assignment statements in @capture macro, so we call it
  #outside the test macro 
  ret = @capture ex (~x)^(~x)
  @test ret
  @test @isdefined x
  @test x === :a

  ex = :(b^a)
  ret = @capture ex (~y)^(~y)
  @test !ret
  @test !(@isdefined y)

  ret = @capture :(a + b) (+)(~~z)
  @test ret
  @test @isdefined z
  @test all(z .=== arguments(:(a + b)))

  #a more typical way to use the @capture macro

  f(x) =
    if @capture x (~w)^(~w)
      w
    end

  @test f(:(b^b)) == :b
  @test isnothing(f(:(b + b)))

  x = 1
  r = (@capture x ~x)
  @test r == true
end
module QuxTest
using Metatheory, Test, TermInterface
struct Qux
  args
  Qux(args...) = new(args)
end
TermInterface.iscall(::Qux) = true
TermInterface.isexpr(::Qux) = true
TermInterface.head(::Qux) = Qux
TermInterface.operation(::Qux) = Qux
TermInterface.children(x::Qux) = [x.args...]
TermInterface.arguments(x::Qux) = [x.args...]

function test()
  @test (@rule Qux(1, 2) => "hello")(Qux(1, 2)) == "hello"
  @test (@rule Qux(1, 2) => "hello")(Qux(3, 4)) === nothing
  @test (@rule Qux(1, 2) => "hello")(1) === nothing
  @test (@rule 1 => "hello")(1) == "hello"
  @test (@rule 1 => "hello")(Qux(1, 2)) === nothing
  @test (@capture Qux(1, 2) Qux(1, 2))
  @test false == (@capture Qux(1, 2) Qux(3, 4))
end
end


module LuxTest
using Metatheory, Test, TermInterface
using Metatheory: @matchable

@matchable struct Lux
  a
  b
end

function test()
  @test (@rule Lux(1, 2) => "hello")(Lux(1, 2)) == "hello"
  @test (@rule Qux(1, 2) => "hello")(Lux(3, 4)) === nothing
  @test (@rule Qux(1, 2) => "hello")(1) === nothing
  @test (@rule 1 => "hello")(1) == "hello"
  @test (@rule 1 => "hello")(Lux(1, 2)) === nothing
  @test (@capture Lux(1, 2) Lux(1, 2))
  @test false == (@capture Lux(1, 2) Lux(3, 4))
end
end

@testset "Matchable struct" begin
  QuxTest.test()
  LuxTest.test()
end
