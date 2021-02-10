
@testset "Reduction Basics" begin
	t = @theory begin
	    a + a => 2a
	    x / x => 1
	    x * 1 => x
	end

    # basic theory to check that everything works
    @test rewrite(:(a + a), t) == :(2a)
    @test rewrite(:(a + a), t) == :(2a)
    @test rewrite(:(a + (x * 1)), t) == :(a + x)
	@test rewrite(:(a + (a * 1)), t; order=:inner) == :(2a)
end

t = @theory begin
	a + a => 2a
	x / x => 1
	x * 1 => x
end
@testset "Precompiling Theories" begin
	@test @time rewrite(:(a + a), t) == :(2a)
	@test @time rewrite(:(a + a), t) == :(2a)
    @test @time rewrite(:(a + (x * 1)), t) == :(a + x)

	ct = @compile_theory t
	@test t isa Vector{Rule} # Vector{Rule} == Theory
	@test ct isa Function  # Callable Function

    # basic theory to check that everything works
    @test @time rewrite(:(a + a), ct) == :(2a)
    @test @time rewrite(:(a + a), ct) == :(2a)
    @test @time rewrite(:(a + (x * 1)), ct) == :(a + x)
	@test @time rewrite(:(a + (a * 1)), ct; order=:inner) == :(2a)
end


import Base.(+)
@testset "Extending Algebra Operators" begin
    t = @theory begin
        a + a => 2a
    end

    # Let's extend an operator from base, for sake of example
    function +(x::Symbol, y)
        rewrite(:($x + $y), t)
    end

    @test (:x + :x) == :(2x)
end


## Free Monoid

@testset "Free Monoid - Overriding identity" begin
    # support symbol literals
	symbol_monoid = @theory begin
		a ⋅ :ε => a
		:ε ⋅ a => a
		a::Symbol => a
		a::Symbol ⋅ b::Symbol |> Symbol(String(a) * String(b))
		i |> error("unsupported ", i)
	end;

    @test rewrite(:(ε ⋅ a ⋅ ε ⋅ b ⋅ c ⋅ (ε ⋅ ε ⋅ d) ⋅ e), symbol_monoid; order=:inner) == :abcde
	@test_throws Exception rewrite(:(ε ⋅ 2), symbol_monoid; order=:inner) == :abcde
end

## Interpolation should be possible at runtime


@testset "Calculator" begin
	calculator = @theory begin
		x::Number ⊕ y::Number |> x + y
		x::Number ⊗ y::Number |> x * y
		x::Number ⊖ y::Number |> x ÷ y
		x::Symbol => x
		x::Number => x
	end;
	a = 10

	@test rewrite(:(3 ⊕ 1 ⊕ $a), calculator; order=:inner) == 14
end

##
@testset "Type assertions and destructuring" begin
    # let's try type assertions and destructuring
    t = @theory begin
        f(a::Number) => a
        f(a...) => a
    end

    @test rewrite(:(f(3)), t) == 3
    @test rewrite(:(f(2, 3)), t) == [2, 3]

    # destructuring in right hand
    n = @theory begin
        f(a...) => +(a...)
    end

    @test rewrite(:(f(2, 3)), n) == :(2 + 3)
    @test rewrite(:(f(a, b, c, d)), n) == :(((a + b) + c) + d)
end

## Direct rules
@testset "Direct Rules" begin
    t = @theory begin
        # maps
        a * b |> ((a isa Number && b isa Number) ? a * b : :(a * b))
    end
    @test rewrite(:(3 * 1), t) == 3

    t = @theory begin
        # maps
        a::Number * b::Number |> a * b
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

@testset "Subtyping" begin
	t = @theory begin
		a::AirVehicle * b => "flies"
		a::GroundVehicle * b => "doesnt_fly"
	end

	sf = rewrite(:($airpl * c), t; m=@__MODULE__)
	df = rewrite(:($car * c), t; m=@__MODULE__)

    @test sf == "flies"
    @test df == "doesnt_fly"
end


## Multiplicative Monoid

mult_monoid = @commutative_monoid Int (*) 1 (*)

@testset "Multiplication Monoid" begin
	res_macro = @rewrite (3 * (1 * 2)) mult_monoid
	res_sym = rewrite(:(3 * (1 * 2)), mult_monoid; order=:inner)
	res_macro_2 = @rewrite (3 * (1 * 2)) mult_monoid inner
	res_macro_3 = @rewrite (2a * (3 * 2)) mult_monoid inner

	@test res_macro == 6
	@test res_macro_2 == 6
	@test res_sym == 6
	@test res_macro_3 == :(12a)
end

addition_group = @abelian_group Int (+) 0 (-) (+) ;
@testset "Addition Abelian Group" begin
	zero = @rewrite ((x+y) +  -(x+y)) addition_group
	@test zero == 0
end

distr = @distrib (*) (+)
Z = mult_monoid ∪ addition_group ∪ distr;
@testset "Composing Theories, distributivity" begin
	res_1 = @rewrite ((2 + (b + -b)) * 3) * (a + b) Z inner
	e = @rewrite (2 * (3 + b + (4 * 2))) Z inner

	@test res_1 == :(6a+6b)
	@test e == :(22+2b)
end

logids = @theory begin
	x * x => x^2
	x^n * x |> :($x^($(n+1)))
	x * x^n |> :($x^($(n+1)))
	a * (a * b) => a^2 * b
	a * (b * a) => a^2 * b
	(a * b) * a => a^2 * b
	(b * a) * a => a^2 * b
	# catch e as ℯ
	:e => ℯ
	log(a^n) => n * log(a)
	log(x * y) => log(x) * log(y)
	log(1) => 0
	log(:ℯ) => 1
	:ℯ^(log(x)) => x
end;

t = logids ∪ Z;
@testset "Symbolic Logarithmic Identities, Composing Theories" begin
    @test rewrite(:(log(ℯ)), t) == 1
    @test rewrite(:(log(x)), t) == :(log(x))
    @test rewrite(:(log(ℯ^3)), t) == 3
    @test rewrite(:(log(a^3)), t) == :(3 * log(a))
    # Reduce.jl wtf u doing? log(:x^-2 * ℯ^3) = :(log(5021384230796917 / (250000000000000 * x ^ 2)))

    @test rewrite(:(log(x^2 * ℯ^3)), t) == :((6 * log(x)))
    @time @test rewrite(:(log(x^2 * ℯ^(log(x)))), t; order=:inner) == :(3 * log(x))
end


using Calculus: differentiate
diff = @theory begin
	∂(y)/∂(x) |> world.differentiate(y, x)
	a * (1/x) => a/x
	a * 0 => 0
	0 * a => 0
end
finalt = t ∪ diff
@testset "Symbolic Differentiation, Accessing Outer Variables" begin
	@test rewrite(:(∂( log(x^2 * ℯ^(log(x))) )/∂(x)), finalt; order=:inner, m=@__MODULE__) == :(3/x)
	@test (@rewrite ∂( log(x^2 * ℯ^(log(x))) )/∂(x) finalt inner) == :(3/x)
end;

## let's loop this
@testset "Reduction loop should return." begin
    t = @theory begin
        a + b => b + a
    end

    @test :(a+b) == rewrite(:(a + b), t)

	t = @theory begin
	    a + b => b + a
	    b + a => a + b
	end

	@test :(a+b) == rewrite(:(a + b), t)
end



## comparisons
@test_skip t = @theory begin
    a ∈ b => a
end

@test_skip @rewrite a ∈ b ∈ c t
