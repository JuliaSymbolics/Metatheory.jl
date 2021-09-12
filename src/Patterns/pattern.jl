using AutoHashEquals
using TermInterface

"""
Abstract type representing a pattern used in all the various pattern matching backends. 
You can use the `Pattern` constructor to recursively convert an `Expr` (or any type satisfying [`Metatheory.TermInterface`](@ref)) to a [`Pattern`](@ref).
"""
abstract type Pattern end

Base.isequal(a::Pattern, b::Pattern) = false
TermInterface.arity(p::Pattern) = 0
"""
A ground pattern contains no pattern variables and 
only literal values to match.
"""
isground(p::Pattern) = false
isground(x) = true # literals

# PatVar is equivalent to SymbolicUtils's Slot
"""
    PatVar{P}(name, debrujin_index, predicate::P)

Pattern variables will first match on one subterm
and instantiate the substitution to that subterm.

Matcher pattern may contain pattern variables with attached predicates,
where `predicate` is a function that takes a matched expression and returns a
boolean value. Such a slot will be considered a match only if `f` returns true.

`predicate` can also be a `Type{<:t}`, this predicate is called a 
type assertion. Type assertions on a `PatVar`, will match if and only if 
the type of the matched term for the pattern variable is a subtype of `T`. 
"""
mutable struct PatVar{P} <: Pattern 
    name::Symbol 
    idx::Int 
    predicate::P 
end
function Base.isequal(a::PatVar, b::PatVar)
    # (a.name == b.name)
    a.idx == b.idx
end
PatVar(var) = PatVar(var, -1, alwaystrue)


"""
If you want to match a variable number of subexpressions at once, you will need
a **segment pattern**. 
A segment pattern represents a vector of subexpressions matched. 
You can attach a predicate `g` to a segment variable. In the case of segment variables `g` gets a vector of 0 or more 
expressions and must return a boolean value. 
"""
struct PatSegment{P} <: Pattern
    name::Symbol
    predicate::P
    hash::Ref{UInt}
end

PatSegment(v) = new{typeof(alwaystrue)}(v, alwaystrue, Ref{UInt}(0))

function Base.hash(t::PatSegment, salt::UInt)
    !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
    h = t.hash[]
    !iszero(h) && return h
    h′ = hash(t.var, hash(t.predicate, salt))
    t.hash[] = h′
    return h′
end

"""
Term patterns will match
on terms of the same `arity` and with the same 
function symbol `operation` and expression head `exprhead`.
"""
struct PatTerm <: Pattern
    exprhead::Any
    operation::Any
    args::Vector{Pattern}
    hash::Ref{UInt}
    PatTerm(eh, op, args) = new(eh, op, args, Ref{UInt}(0))
end
TermInterface.istree(::Type{PatTerm}) = true
TermInterface.exprhead(e::PatTerm) = e.exprhead
TermInterface.operation(p::PatTerm) = p.operation
TermInterface.arguments(p::PatTerm) = p.args
TermInterface.arity(p::PatTerm) = length(arguments(p))

function Base.hash(t::PatTerm, salt::UInt)
    !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
    h = t.hash[]
    !iszero(h) && return h
    h′ = hash(t.exprhead, hash(t.operation, hash(t.args, salt)))
    t.hash[] = h′
    return h′
end

isground(p::PatTerm) = all(isground, p.args)


# ==============================================
# ================== PATTERN VARIABLES =========
# ==============================================

"""
Collects pattern variables appearing in a pattern into a vector of symbols
"""
patvars(p::PatVar, s) = push!(s, p.name)
patvars(p::PatSegment, s) = patvars(p.var, s)

function patvars(p::PatTerm, s)
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

function Base.setindex!(p::PatVar, pvars)
    p.idx = findfirst((==)(p.name), pvars)
end
Base.setindex!(p::PatSegment, pvars) = setindex!(p.var, pvars)

function Base.setindex!(p::PatTerm, pvars)
    for x ∈ p.args 
        setindex!(x, pvars)
    end
end 


