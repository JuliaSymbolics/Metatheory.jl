using Parameters

import Base.==

abstract type Rule end
# Must override
==(a::Rule, b::Rule) = false


abstract type SymbolicRule <: Rule end

"""
Rules defined as `left_hand => right_hand` are
called *symbolic rewrite* rules. Application of a *rewrite* Rule
is a replacement of the `left_hand` pattern with
the `right_hand` substitution, with the correct instantiation
of pattern variables. Function call symbols are not treated as pattern
variables, all other identifiers are treated as pattern variables.
Literals such as `5, :e, "hello"` are not treated as pattern
variables.


```julia
Rule(:(a * b => b * a))
```
"""
@auto_hash_equals struct RewriteRule <: SymbolicRule 
    left::Pattern
    right::Pattern
    patvars::Vector{Symbol}
    function RewriteRule(l,r)
        pvars = patvars(l) ∪ patvars(r)
        # sort!(pvars)
        setindex!(l, pvars)
        setindex!(r, pvars)
        new(l,r,pvars)
    end
end

# =============================================================================


abstract type BidirRule <: SymbolicRule end

"""
This type of *anti*-rules is used for checking contradictions in the EGraph
backend. If two terms, corresponding to the left and right hand side of an
*anti-rule* are found in an [`EGraph`], saturation is halted immediately. 
"""
@auto_hash_equals struct UnequalRule <: BidirRule 
    left::Pattern
    right::Pattern
    patvars::Vector{Symbol}
    function UnequalRule(l,r)
        pvars = patvars(l) ∪ patvars(r)
        # sort!(pvars)
        setindex!(l, pvars)
        setindex!(r, pvars)
        new(l,r,pvars)
    end
end

"""
```julia
Rule(:(a * b == b * a))
```
"""
@auto_hash_equals struct EqualityRule <: BidirRule 
    left::Pattern
    right::Pattern
    patvars::Vector{Symbol}
    function EqualityRule(l,r)
        pvars = patvars(l) ∪ patvars(r)
        # sort!(pvars)
        setindex!(l, pvars)
        setindex!(r, pvars)
        new(l,r,pvars)
    end
end

"""
Rules defined as `left_hand |> right_hand` are
called `dynamic` rules. Dynamic rules behave like anonymous functions.
Instead of a symbolic substitution, the right hand of
a dynamic `|>` rule is evaluated during rewriting:
matched values are bound to pattern variables as in a
regular function call. This allows for dynamic computation
of right hand sides.

Dynamic rule
```julia
Rule(:(a::Number * b::Number |> a*b))
```
"""
@auto_hash_equals struct DynamicRule <: Rule 
    left::Pattern
    right::Any
    patvars::Vector{Symbol} # useful set of pattern variables
    function DynamicRule(l, r) 
        pvars = patvars(l)
        # sort!(pvars)
        setindex!(l, pvars)
        new(l, r, pvars)
    end
end
