using AutoHashEquals

"""
Abstract type representing a pattern used in all the various pattern matching backends. 
You can use the `Pattern` constructor to recursively convert an `Expr` (or any type satisfying [`Metatheory.TermInterface`](@ref)) to a [`Pattern`](@ref).
"""
abstract type Pattern end

import Base.==
==(a::Pattern, b::Pattern) = false

"""
Pattern variables will first match on any subterm
and instantiate the substitution to that subterm. 
"""
mutable struct PatVar <: Pattern
    name::Symbol
    idx::Int
end
==(a::PatVar, b::PatVar) = (a.name == b.name)
PatVar(var) = PatVar(var, -1)


"""
A pattern literal will match only against an instance of itself.
Example:
```julia
PatLiteral(2)
```
Will match only against values that are equal (using `Base.(==)`) to 2.

```julia
PatLiteral(:a)
```
Will match only against instances of the literal symbol `:a`.
"""
@auto_hash_equals struct PatLiteral{T} <: Pattern
    val::T
end

"""
Type assertions on a [`PatVar`](@ref), will match if and only if 
the type of the matched term for the pattern variable `var` is a subtype 
of `type`.
"""
@auto_hash_equals struct PatTypeAssertion <: Pattern
    var::PatVar
    type::Type
end


@auto_hash_equals struct PatSplatVar <: Pattern
    var::PatVar
end


"""
This type of pattern will match if and only if 
the two subpatterns exist in the same equivalence class,
in the e-graph on which the matching is performed.
**Can be used only in the e-graphs backend**
"""
@auto_hash_equals struct PatEquiv <: Pattern
    left::Pattern
    right::Pattern
end

"""
Term patterns will match
on terms of the same `arity` and with the same 
function symbol (`head`).
"""
@auto_hash_equals struct PatTerm <: Pattern
    head::Any
    args::Vector{Pattern}
    metadata::NamedTuple
end
TermInterface.arity(p::PatTerm) = length(p.args)
PatTerm(head, args) = PatTerm(head, args, (;))

"""
This pattern type matches on a function application 
but instead of strictly matching on a head symbol, 
it has a pattern variable as head. It can be used for 
example to match arbitrary function calls.
"""
@auto_hash_equals struct PatAllTerm <: Pattern
    head::PatVar
    args::Vector{Pattern}
    metadata::NamedTuple
end
TermInterface.arity(p::PatAllTerm) = length(p.args)
PatAllTerm(head, args) = PatAllTerm(head, args, (;))

"""
Collects pattern variables appearing in a pattern into a vector of symbols
"""
patvars(p::PatLiteral, s) = s 
patvars(p::PatVar, s) = push!(s, p.name)
patvars(p::PatTypeAssertion, s) = patvars(p.var, s)
patvars(p::PatSplatVar, s) = patvars(p.var, s)
function patvars(p::PatEquiv, s)
    patvars(p.left, s)
    patvars(p.right, s)    
end

function patvars(p::PatTerm, s)
    for x ∈ p.args 
        patvars(x, s)
    end
    return s
end 

function patvars(p::PatAllTerm, s)
    push!(s, p.head.name)
    for x ∈ p.args 
        patvars(x, s)
    end
    return s
end 

function patvars(p::Pattern)
    unique(patvars(p, Symbol[]))
end 



setindex!(p::PatLiteral, pvars) = nothing 
function setindex!(p::PatVar, pvars)
    p.idx = findfirst((==)(p.name), pvars)
end
setindex!(p::PatTypeAssertion, pvars) = setindex!(p.var, pvars)
setindex!(p::PatSplatVar, pvars) = setindex!(p.var, pvars)


function setindex!(p::PatEquiv, pvars)
    setindex!(p.left, pvars)
    setindex!(p.right, pvars)
end 

function setindex!(p::PatTerm, pvars)
    for x ∈ p.args 
        setindex!(x, pvars)
    end
end 

function setindex!(p::PatAllTerm, pvars)
    setindex!(p.head, pvars)
    for x ∈ p.args 
        setindex!(x, pvars)
    end
end 