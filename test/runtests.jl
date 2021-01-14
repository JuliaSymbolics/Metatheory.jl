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
@test sym_reduce(:(a + a), t) == :(2a)
@test (@reduce a + (x * 1) t) == :(a + x)

# Let's extend an operator from base, for sake of example
import Base.(+)
function +(x::Symbol, y)
    :(@reduce $x + $y t) |> eval
end

:a + :a

## Let's build a more complex theory from basic calculus facts
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
    log(x) ↦ (x == :ℯ ? 1 : :(log($x)))
    a::Number * b::Number ↦ a*b
end

@test (@reduce log(ℯ) t) == 1
@test (@reduce log(x) t) == :(log(x))

@test (@reduce log(ℯ ^ 3) t) == 3

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
    a::Number * b::Number ↦ a * b
end


@test (@reduce 3*1 t) == 3

# let's try type assertions and destructuring
t = @theory begin
    f(a::Number) => a
    f(a...) => a
end

@test (@reduce f(3) t) == 3
@test (@reduce f(2, 3) t) == [2,3]

# destructuring in right hand
t = @theory begin
    f(a...) => +(a...)
end

@test (@reduce f(2, 3) t) == :(2 + 3)
@test (@reduce f(a,b,c,d) t) == :(a+b+c+d)

# let's try summing things up
R = @theory begin
    # + operator
    +(xs...) + +(ys...) => +(xs..., ys...) # associative both ways
    a + +(xs...) => +(a, xs...)
    +(xs...) + a => +(xs..., a)
    a+a => 2a

    # * operator
    a * 1 => a
    1 * a => a
    *(xs...) * *(ys...) => *(xs..., ys...)
    a * *(xs...) => *(a, xs...)
    *(xs...) * a => *(xs..., a)


    # * distributes over +
    a * +(bs...) => +( [:($a * $b) for b ∈ bs]... )
    +(bs...) * a => +( [:($b * $a) for b ∈ bs]... )
end

sym_reduce(:(x*1), R)

@test (@reduce x + (y + z) R) == :(x+y+z)
@test (@reduce (x + y) + z R) == :(x+y+z)
@test (@reduce (x + y) + (z + k) R) == :(x+y+z+k)

@test (@reduce x*1 R) == :x
@test (@reduce x*(y*z) R) == :(x*y*z)

@test (@reduce x*(y+z) R) == :(x*y + x*z)
@test (@reduce (b+c)*a R) == :(b*a + c*a)

# let's loop this
#t = @theory begin
#    a + b => b + a
#end

#@reduce a + b t


## comparisons
t = @theory begin
    a ∈ b => a
end

@reduce a ∈ b ∈ c t


## Cases on custom types

struct Airplane end

struct Car end

t = @theory begin
    a::Airplane * b => :airp
    a::Car * b => :car
end

@reduce $(Airplane()) * b t
