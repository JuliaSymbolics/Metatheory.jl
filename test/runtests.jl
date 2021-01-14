using Test

include("../src/util.jl")
include("../src/theory.jl")
include("../src/reduce.jl")

@rule a + a => 2a


# OK tests

theory = :(quote
    $a + $(&a) => :(2 * $a)
    $b + $(&b) + $(&b) => :(3 * $a)
end) |> rmlines

theory_macro = @theory begin
           a + a => 2a
           b + b + b => 3b
           end


r = Rule(:(a+a => 2a))
rm = @rule a + a => 2a

@test r.left == rm.left
@test r.right == rm.right
@test r.pattern == rm.pattern

# basic theory to check that everything works
t = @theory begin
    a + a => 2a
    x / x => 1
    x * 1 => x
end;


@test (@reduce a + a t) == :(2a)

@test (@reduce a + (x * 1) t) == :(a + x)


# Let's build a more complex theory from basic calculus facts
t = @theory begin
    f(x) => 42
    !a => f(x)
    a + a => 2a
    a * a => a^2
    x / x => 1
    x^-1 => 1 / x
end



t = @theory begin
    log(a^n) => n * log(a)
    log(a * b) => log(a) + log(b)
    log(1) => 0
    #e^(log(x)) => x
    log(x) ↦ (x == :ℯ ? 1 : :(log($x)))
end

@test (@reduce log(ℯ) t) == 1
@test (@reduce log(ℯ ^ 3) t) == :(3*1)

@reduce log(a ^ 3) t

# Reduce.jl wtf u doing? log(:x^-2 * ℯ^3) = :(log(5021384230796917 / (250000000000000 * x ^ 2)))
@reduce log(x^2 * ℯ^3) t

@reduce log(x^2 * ℯ^(log(x))) t

@reduce log(x^2 * ℯ^(log(x))) t


t = @theory begin
    # maps
    a * b ↦ ((a isa Number && b isa Number) ? a * b : :(a*b))
end

t = @theory begin
    # maps
    $(a::Number) * $(b::Number) ↦ a * b
end


@test (@reduce 3*1 t) == 3

t = @theory begin
    # maps
    $(a::Number) + $(b::Number) ↦ a + b
    $(a::Number) * $(b::Number) ↦ a * b

    # Associativity of * on numbers
    $(a::Number) * ($(b::Number) * c) ↦ :($(a * b) * $c)
    $(a::Number) * (c * $(b::Number)) ↦ :($(a * b) * $c)

    a + $(b::Number) * a ↦ :($(b + 1) * $a)
    $(b::Number) * a + a ↦ :($(b + 1) * $a)
end

@test (@reduce 3*1 t) == 3
@test (@reduce 3*(2*a) t) == :(6a)

@test (@reduce 3a + a t) == :(4a)

@test (@reduce 3(x*z) + (x*z) t) == :(4(x*z))



# let's loop this
#t = @theory begin
#    a + b => b + a
#end

#@reduce a + b t


t = @theory begin
    a ∈ b => a
end

@reduce a ∈ b ∈ c t
