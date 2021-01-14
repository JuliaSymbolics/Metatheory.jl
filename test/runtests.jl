using Test

include("../src/util.jl")
include("../src/Metatheory.jl")

using Main.Metatheory

@testset "Rule making" begin
    @test (@rule a + a => 2a) isa Rule
    r = Rule(:(a + a => 2a))
    rm = @rule a + a => 2a
    @test r.left == rm.left
    @test r.right == rm.right
    @test r.pattern == rm.pattern
end

@testset "Theories" begin
    theory = :(
        begin
            :($a + $(&a)) => :(2 * $a)
            :($b + $(&b) + $(&b)) => :(3 * $b)
            :($i) => i
        end
    ) |> rmlines
    theory_macro = @theory begin
        a + a => 2a
        b + b + b => 3b
    end
    @test (makeblock(theory_macro) == theory)
end

t = @theory begin
    a + a => 2a
    x / x => 1
    x * 1 => x
end

@testset "Reduction Basics" begin
    # basic theory to check that everything works
    @test sym_reduce(:(a + a), t) == :(2a)
    @test sym_reduce(:(a + a), t) == :(2a)
    @test sym_reduce(:(a + (x * 1)), t) == :(a + x)
end


import Base.(+)
@testset "Extending Algebra Operators" begin
    t = @theory begin
        a + a => 2a
    end

    # Let's extend an operator from base, for sake of example
    function +(x::Symbol, y)
        sym_reduce(:($x + $y), t)
    end

    @test (:x + :x) == :(2x)
end


## Free Monoid

@testset "Free Monoid" begin
    # support symbol literals
    free_monoid = @theory begin
        a ⋅ :ε => a
        :ε ⋅ a => a
        a::Symbol ⋅ b::Symbol ↦ Symbol(String(a) * String(b))
    end

    @test sym_reduce(:(ε ⋅ a ⋅ ε ⋅ b ⋅ c ⋅ (ε ⋅ ε ⋅ d) ⋅ e), free_monoid) == :abcde
end


## Take advantage of subtyping.
# Subtyping in Julia has been formalized in this paper
# [Julia Subtyping: A Rational Reconstruction](https://benchung.github.io/papers/jlsub.pdf)

abstract type Vehicle end
abstract type GroundVehicle <: Vehicle end
abstract type AirVehicle <: Vehicle end
struct Airplane <: AirVehicle end
struct Car <: GroundVehicle end

t = @theory begin
    a::AirVehicle * b => "flies"
    a::GroundVehicle * b => "doesnt_fly"
end

sf = @reduce $(Airplane()) * c t
df = @reduce $(Car()) * b t
@testset "Subtyping" begin
    @test sf == "flies"
    @test df == "doesnt_fly"
end


## Let's build a more complex theory from basic calculus facts
@test_skip t = @theory begin
    f(x) => 42
    !a => f(x)
    a + a => 2a
    a * a => a^2
    x / x => 1
    x^-1 => 1 / x
end


@testset "Symbolic Logarithmic Identities" begin
    t = @theory begin
        log(a^n) => n * log(a)
        log(a * b) => log(a) + log(b)
        log(1) => 0
        log(:ℯ) => 1
        :ℯ^(log(x)) => x
        #log(x) ↦ (x == :ℯ ? 1 : :(log($x)))
        a::Number * b::Number ↦ a * b
        a::Number * b + b ↦ :($(a + 1) * $b)
        x * 1 => x
        1 * x => x
    end
    @test sym_reduce(:(log(ℯ)), t) == 1
    @test sym_reduce(:(log(x)), t) == :(log(x))
    @test sym_reduce(:(log(ℯ^3)), t) == 3
    @test sym_reduce(:(log(a^3)), t) == :(3 * log(a))
    # Reduce.jl wtf u doing? log(:x^-2 * ℯ^3) = :(log(5021384230796917 / (250000000000000 * x ^ 2)))

    @test sym_reduce(:(log(x^2 * ℯ^3)), t) == :(2 * log(x) + 3)
    @test sym_reduce(:(log(x^2 * ℯ^(log(x)))), t) == :(3 * log(x))
end


@testset "Direct Rules" begin
    t = @theory begin
        # maps
        a * b ↦ ((a isa Number && b isa Number) ? a * b : :(a * b))
    end
    @test sym_reduce(:(3 * 1), t) == 3

    t = @theory begin
        # maps
        a::Number * b::Number ↦ a * b
    end
    @test sym_reduce(:(3 * 1), t) == 3
end




@testset "Type assertions and destructuring" begin
    # let's try type assertions and destructuring
    t = @theory begin
        f(a::Number) => a
        f(a...) => a
    end

    @test sym_reduce(:(f(3)), t) == 3
    @test sym_reduce(:(f(2, 3)), t) == [2, 3]

    # destructuring in right hand
    n = @theory begin
        f(a...) => +(a...)
    end

    @test sym_reduce(:(f(2, 3)), n) == :(2 + 3)
    @test sym_reduce(:(f(a, b, c, d)), n) == :(a + b + c + d)
end

@testset "Spicing things up" begin
    # let's try spicing things up
    R = @theory begin
        # + operator, left and right associative
        # n-arity
        +(xs...) + +(ys...) => +(xs..., ys...)
        a + +(xs...) => +(a, xs...)
        +(xs...) + a => +(xs..., a)
        a + a => 2a

        # * operator
        a * 1 => a
        1 * a => a
        *(xs...) * *(ys...) => *(xs..., ys...)
        a * *(xs...) => *(a, xs...)
        *(xs...) * a => *(xs..., a)

        # * distributes over +
        a * +(bs...) => +([:($a * $b) for b ∈ bs]...)
        +(bs...) * a => +([:($b * $a) for b ∈ bs]...)

        # we can simplify over number literals
        x::Number + y::Number ↦ x+y
        x::Number * y::Number ↦ x*y
    end

    sym_reduce(:(x * 1), R)

    @test sym_reduce(:(x + (y + z)), R) == :(x + y + z)
    @test sym_reduce(:((x + y) + z), R) == :(x + y + z)
    @test sym_reduce(:((x + y) + (z + k)), R) == :(x + y + z + k)
    @test sym_reduce(:(x * 1), R) == :x
    @test sym_reduce(:(x * (y * z)), R) == :(x * y * z)
    @test sym_reduce(:(x * (y + z)), R) == :(x * y + x * z)
    @test sym_reduce(:((b + c) * a), R) == :(b * a + c * a)
end

# let's loop this

@testset "Reduction loop should error. Bound on iterations." begin
    t = @theory begin
        a + b => b + a
    end

    @test_throws Exception sym_reduce(:(a + b), t)
end

## comparisons
@test_skip t = @theory begin
    a ∈ b => a
end

@test_skip @reduce a ∈ b ∈ c t
