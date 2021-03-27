using ExprRules
using AbstractTrees

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