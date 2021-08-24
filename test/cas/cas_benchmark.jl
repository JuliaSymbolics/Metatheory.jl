using ExprRules

using BenchmarkTools
using Random

include("cas_theory.jl")
include("cas_simplify.jl")

grammar = @grammar begin
    Real = x | y | z | a | b | c     # symbol
    Real = -Real
    Real = Real * Real | Real + Real | Real - Real | Real / Real           # julia expression
    Real = _(Base.rand(1.0:100.0))  # special syntax, eval argument of _() at derivation time
    Real = sin(Real) | cos(Real)        # multiple rules on a single line
    Real = |(1:100)                 # same as Real = 4 | 5 | 6
end

Random.seed!(rand(UInt))

for i ∈ 1:100
    rulenode = rand(RuleNode, grammar, :Real, 10)
    println(get_executable(rulenode, grammar))
end

@profview :(4a)         == simplify(:(2a + a + a))
@profview :(a*b*c)      == simplify(:(a * c * b))
@profview :(2x)         == simplify(:(1 * x * 2))
@profview :((a*b)^2)    == simplify(:((a*b)^2))
@profview :((a*b)^6)    == simplify(:((a^2*b^2)^3))
@profview :(a+b+d)      == simplify(:(a + b + (0*c) + d))
@profview :(a+b)        == simplify(:(a + b + (c*0) + d - d))
@profview :(a)          == simplify(:((a + d) - d))
@profview :(a + b + d)  == simplify(:(a + b * c^0 + d))
@profview :(a * b * x ^ (d+y))  == @simplify a * x^y * b * x^d
@profview :(a * b * x ^ 74103)  == @simplify a * x^(12 + 3) * b * x^(42^3)
@profview 1 == @simplify (x+y)^(a*0) / (y+x)^0
@profview 2 == @simplify cos(x)^2 + 1 + sin(x)^2
@profview 2 == @simplify cos(y)^2 + 1 + sin(y)^2
@profview 2 == @simplify sin(y)^2 + cos(y)^2 + 1
@profview :(y + sec(x)^2 ) == @simplify 1 + y + tan(x)^2
@profview :(y + csc(x)^2 ) == @simplify 1 + y + cot(x)^2

@profview :(2x^3) == simplify(:( x * ∂(x^2, x) * x))
