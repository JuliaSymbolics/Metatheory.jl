using Metatheory

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

@testset "Segment Variables" begin
  t = @theory begin
    f(~x, ~~y) => Expr(:call, :ok, (~~y)...)
  end
  sf = rewrite(:(f(1, 2, 3, 4)), t)
  @test sf == :(ok(2, 3, 4))

  t = @theory x y begin
    f(x, y...) => Expr(:call, :ok, y...)
  end
  sf = rewrite(:(f(1, 2, 3, 4)), t)
  @test sf == :(ok(2, 3, 4))

  t = @theory x y begin
    f(x, y...) --> ok(y...)
  end
  sf = rewrite(:(f(1, 2, 3, 4)), t)
  @test sf == :(ok(2, 3, 4))
end


module NonCall
using Metatheory
t = [@rule a b (a, b) --> ok(a, b)]

test() = rewrite(:(x, y), t)
end

@testset "Non-Call expressions" begin
  @test NonCall.test() == :(ok(x, y))
end


@testset "Pattern matcher can match on both function object references and name symbols" begin
  ex = :($(+)($(sin)(x)^2, $(cos)(x)^2))
  r = @rule(sin(~x)^2 + cos(~x)^2 --> 1)

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
  r = (@capture x x)
  @test r == true
end

@testset "Matchable struct" begin
  struct Qux
    args
    Qux(args...) = new(args)
  end
  struct QuxHead
    head
  end
  TermInterface.head(::Qux) = QuxHead(:call)
  TermInterface.head_symbol(q::QuxHead) = q.head
  TermInterface.operation(::Qux) = Qux
  TermInterface.istree(::Qux) = true
  TermInterface.arguments(x::Qux) = [x.args...]
  TermInterface.children(x::Qux) = [operation(x); x.args...]


  @test (@rule Qux(1, 2) => "hello")(Qux(1, 2)) == "hello"
  @test (@rule Qux(1, 2) => "hello")(1) === nothing
  @test (@rule 1 => "hello")(1) == "hello"
  @test (@rule 1 => "hello")(Qux(1, 2)) === nothing
  @test (@capture Qux(1, 2) Qux(1, 2))
  @test false == (@capture Qux(1, 2) Qux(3, 4))


  @matchable struct Lux
    a
    b
  end


  @test (@rule Lux(1, 2) => "hello")(Lux(1, 2)) == "hello"
  @test (@rule Qux(1, 2) => "hello")(1) === nothing
  @test (@rule 1 => "hello")(1) == "hello"
  @test (@rule 1 => "hello")(Lux(1, 2)) === nothing
  @test (@capture Lux(1, 2) Lux(1, 2))
  @test false == (@capture Lux(1, 2) Lux(3, 4))
end
