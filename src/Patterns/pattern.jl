using AutoHashEquals
using TermInterface

"""
Abstract type representing a pattern used in all the various pattern matching backends. 
You can use the `Pattern` constructor to recursively convert an `Expr` (or any type satisfying [`Metatheory.TermInterface`](@ref)) to a [`Pattern`](@ref).
"""
abstract type Pattern end

import Base.==
==(a::Pattern, b::Pattern) = false
TermInterface.arity(p::Pattern) = 0
function isground(p::Pattern)
    false
end

"""
Pattern variables will first match on any subterm
and instantiate the substitution to that subterm. 
"""
mutable struct PatVar <: Pattern
    name::Symbol
    idx::Int
end
function ==(a::PatVar, b::PatVar)
    # (a.name == b.name)
    a.idx == b.idx
end
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
function isground(p::PatLiteral)
    true
end

"""
Type assertions on a [`PatVar`](@ref), will match if and only if 
the type of the matched term for the pattern variable `var` is a subtype 
of `type`.
Type assertions are supported in the left hand of rules
to match and access literal values both when using classic
rewriting and EGraph based rewriting.
To use a type assertion pattern, add `::T` after
a pattern variable in the `left_hand` of a rule.
"""
struct PatTypeAssertion <: Pattern
    var::PatVar
    type::Type
    hash::Ref{UInt}
    PatTypeAssertion(v,t) = new(v, t, Ref{UInt}(0))
end
function Base.hash(t::PatTypeAssertion, salt::UInt)
    !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
    h = t.hash[]
    !iszero(h) && return h
    h′ = hash(t.var,  hash(t.type, salt))
    t.hash[] = h′
    return h′
end


struct PatSplatVar <: Pattern
    var::PatVar
    hash::Ref{UInt}
    PatSplatVar(v) = new(v, Ref{UInt}(0))
end
function Base.hash(t::PatSplatVar, salt::UInt)
    !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
    h = t.hash[]
    !iszero(h) && return h
    h′ = hash(t.var, salt)
    t.hash[] = h′
    return h′
end


"""
This type of pattern will match if and only if 
the two subpatterns exist in the same equivalence class,
in the e-graph on which the matching is performed.
**Can be used only in the e-graphs backend**
"""
struct PatEquiv <: Pattern
    left::Pattern
    right::Pattern
    hash::Ref{UInt}
    PatEquiv(l,r) = new(l,r, Ref{UInt}(0))
end

function ==(a::PatEquiv, b::PatEquiv)
    a.left == b.left && a.right == b.right
end

function Base.hash(t::PatEquiv, salt::UInt)
    !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
    h = t.hash[]
    !iszero(h) && return h
    h′ = hash(t.left,  hash(t.right, salt))
    t.hash[] = h′
    return h′
end

function isground(p::PatEquiv)
   isground(p.left) && isground(p.right)
end

"""
Term patterns will match
on terms of the same `arity` and with the same 
function symbol (`head`).
"""
struct PatTerm <: Pattern
    head::Any
    args::Vector{Pattern}
    hash::Ref{UInt}
    PatTerm(h,args) = new(h,args, Ref{UInt}(0))
end
TermInterface.gethead(p::PatTerm) = p.head
TermInterface.arity(p::PatTerm) = length(p.args)
TermInterface.getargs(p::PatTerm) = p.args

function Base.hash(t::PatTerm, salt::UInt)
    !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
    h = t.hash[]
    !iszero(h) && return h
    h′ = hash(t.head,  hash(t.args, salt))
    t.hash[] = h′
    return h′
end

function isground(p::PatTerm)
    mapreduce(isground, (&), p.args)
end

"""
This pattern type matches on a function application 
but instead of strictly matching on a head symbol, 
it has a pattern variable as head. It can be used for 
example to match arbitrary function calls.
"""
@auto_hash_equals struct PatAllTerm <: Pattern
    head::PatVar
    args::Vector{Pattern}
end
TermInterface.arity(p::PatAllTerm) = length(p.args)


# ==============================================
# ================== PATTERN VARIABLES =========
# ==============================================

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

# ==============================================
# ================== DEBRUJIN INDEXING =========
# ==============================================

Base.setindex!(p::PatLiteral, pvars) = nothing 
function Base.setindex!(p::PatVar, pvars)
    p.idx = findfirst((==)(p.name), pvars)
end
Base.setindex!(p::PatTypeAssertion, pvars) = setindex!(p.var, pvars)
Base.setindex!(p::PatSplatVar, pvars) = setindex!(p.var, pvars)


function Base.setindex!(p::PatEquiv, pvars)
    setindex!(p.left, pvars)
    setindex!(p.right, pvars)
end 

function Base.setindex!(p::PatTerm, pvars)
    for x ∈ p.args 
        setindex!(x, pvars)
    end
end 

function Base.setindex!(p::PatAllTerm, pvars)
    setindex!(p.head, pvars)
    for x ∈ p.args 
        setindex!(x, pvars)
    end
end 

