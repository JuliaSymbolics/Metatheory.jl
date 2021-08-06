using Parameters
using AutoHashEquals
using ..Patterns

import Base.==

abstract type AbstractRule end
# Must override
==(a::AbstractRule, b::AbstractRule) = false


abstract type SymbolicRule <: AbstractRule end

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
    ematch_program::Program
    staged_ematch_fun::Ref{Function}
    function RewriteRule(l,r)
        pvars = patvars(l) ∪ patvars(r)
        # sort!(pvars)
        setindex!(l, pvars)
        setindex!(r, pvars)
        new(l,r,pvars, compile_pat(l), Ref{Function}())
    end
end

function Base.show(io::IO, mime::MIME"text/plain", r::RewriteRule)
    print(io, "$(r.left) => $(r.right)")
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
    ematch_program_l::Program
    ematch_program_r::Program
    staged_ematch_fun_l::Ref{Function}
    staged_ematch_fun_r::Ref{Function}

    function UnequalRule(l,r)
        pvars = patvars(l) ∪ patvars(r)
        extravars = setdiff(pvars, patvars(l) ∩ patvars(r))
        if !isempty(extravars)
            error("unbound pattern variables $extravars when creating bidirectional rule")
        end
        # sort!(pvars)
        setindex!(l, pvars)
        setindex!(r, pvars)
        progl = compile_pat(l)
        progr = compile_pat(r)
        new(l,r,pvars, progl, progr, Ref{Function}(), Ref{Function}())
    end
end

function Base.show(io::IO, mime::MIME"text/plain", r::UnequalRule)
    print(io, "$(r.left) ≠ $(r.right)")
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
    ematch_program_l::Program
    ematch_program_r::Program
    staged_ematch_fun_l::Ref{Function}
    staged_ematch_fun_r::Ref{Function}
    function EqualityRule(l,r)
        pvars = patvars(l) ∪ patvars(r)
        extravars = setdiff(pvars, patvars(l) ∩ patvars(r))
        if !isempty(extravars)
            error("unbound pattern variables $extravars when creating bidirectional rule")
        end
        # sort!(pvars)
        setindex!(l, pvars)
        setindex!(r, pvars)
        progl = compile_pat(l)
        progr = compile_pat(r)
        new(l,r,pvars, progl, progr, Ref{Function}(), Ref{Function}())
    end
end

function Base.show(io::IO, mime::MIME"text/plain", r::EqualityRule)
    print(io, "$(r.left) == $(r.right)")
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
@auto_hash_equals struct DynamicRule <: AbstractRule 
    left::Pattern
    right::Any
    patvars::Vector{Symbol} # useful set of pattern variables
    ematch_program::Program
    staged_ematch_fun::Ref{Function}
    function DynamicRule(l, r) 
        pvars = patvars(l)
        # sort!(pvars)
        setindex!(l, pvars)
        new(l, r, pvars, compile_pat(l), Ref{Function}())
    end
end

function Base.show(io::IO, mime::MIME"text/plain", r::DynamicRule)
    print(io, "$(r.left) |> $(r.right)")
end