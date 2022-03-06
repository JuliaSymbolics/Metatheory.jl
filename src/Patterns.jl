module Patterns 

using Metatheory: binarize, cleanast, alwaystrue
using AutoHashEquals
using TermInterface


"""
Abstract type representing a pattern used in all the various pattern matching backends. 
"""
abstract type AbstractPat end


struct UnsupportedPatternException <: Exception
    p::AbstractPat
end

Base.showerror(io::IO, e::UnsupportedPatternException) = 
    print(io, "Pattern ", e.p, " is unsupported in this context")


Base.isequal(a::AbstractPat, b::AbstractPat) = false
TermInterface.arity(p::AbstractPat) = 0
"""
A ground pattern contains no pattern variables and 
only literal values to match.
"""
isground(p::AbstractPat) = false
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
mutable struct PatVar{P} <: AbstractPat 
    name::Symbol 
    idx::Int 
    predicate::P 
end
function Base.isequal(a::PatVar, b::PatVar)
    # (a.name == b.name)
    a.idx == b.idx
end
PatVar(var) = PatVar(var, -1, alwaystrue)
PatVar(var, i) = PatVar(var, i, alwaystrue)

"""
If you want to match a variable number of subexpressions at once, you will need
a **segment pattern**. 
A segment pattern represents a vector of subexpressions matched. 
You can attach a predicate `g` to a segment variable. In the case of segment variables `g` gets a vector of 0 or more 
expressions and must return a boolean value. 
"""
mutable struct PatSegment{P} <: AbstractPat
    name::Symbol
    idx::Int
    predicate::P
    # hash::Ref{UInt}
end

PatSegment(v) = PatSegment(v, -1, alwaystrue)
PatSegment(v, i) = PatSegment(v, i, alwaystrues)
# PatSegment(v, i, p) = PatSegment{typeof(p)}(v, i, p), Ref{UInt}(0))


# function Base.hash(t::PatSegment, salt::UInt)
#     !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
#     h = t.hash[]
#     !iszero(h) && return h
#     h′ = hash(t.name, hash(t.predicate, salt))
#     t.hash[] = h′
#     return h′
# end

"""
Term patterns will match
on terms of the same `arity` and with the same 
function symbol `operation` and expression head `exprhead`.
"""
struct PatTerm <: AbstractPat
    exprhead::Any
    operation::Any
    args::Vector
    mod::Module # useful to match against function head symbols and function objs at the same time
    PatTerm(eh, op, args, mod) = new(eh, op, args, mod) #Ref{UInt}(0))
end
TermInterface.istree(::PatTerm) = true
TermInterface.exprhead(e::PatTerm) = e.exprhead
TermInterface.operation(p::PatTerm) = p.operation
TermInterface.arguments(p::PatTerm) = p.args
TermInterface.arity(p::PatTerm) = length(arguments(p))
TermInterface.metadata(p::PatTerm) = p.mod

function TermInterface.similarterm(x::PatTerm, head, args, symtype=nothing; metadata=@__MODULE__, exprhead=:call)
    PatTerm(exprhead, head, args, metadata)
end

# function Base.hash(t::PatTerm, salt::UInt)
#     !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
#     h = t.hash[]
#     !iszero(h) && return h
#     h′ = hash(t.exprhead, hash(t.operation, hash(t.args, salt)))
#     t.hash[] = h′
#     return h′
# end

isground(p::PatTerm) = all(isground, p.args)


# ==============================================
# ================== PATTERN VARIABLES =========
# ==============================================

"""
Collects pattern variables appearing in a pattern into a vector of symbols
"""
patvars(p::PatVar, s) = push!(s, p.name)
patvars(p::PatSegment, s) = push!(s, p.name)
patvars(p::PatTerm, s) = (patvars(operation(p), s); foreach(x -> patvars(x, s), arguments(p)) ; s)
patvars(x, s) = s

patvars(p) = unique!(patvars(p, Symbol[]))


# ==============================================
# ================== DEBRUJIN INDEXING =========
# ==============================================

function setdebrujin!(p::Union{PatVar,PatSegment}, pvars)
    p.idx = findfirst((==)(p.name), pvars)
end

# literal case
setdebrujin!(p, pvars) = nothing

function setdebrujin!(p::PatTerm, pvars) 
    setdebrujin!(operation(p), pvars)
    foreach(x -> setdebrujin!(x, pvars), p.args)
end

#TODO ADD ORIGINAL CODE OF PREDICATE TO PATVAR ?
function to_expr(x::PatVar)
    if x.predicate == alwaystrue
        Expr(:call, :~, x.name)
    else
        Expr(:call, :~, Expr(:(::), x.name, x.predicate))
    end
end

to_expr(x::Any) = x

function to_expr(x::PatSegment)
    Expr(:...,  x.predicate == alwaystrue ? Expr(:call, :~, x.name) : 
        Expr(:call, :~, Expr(:(::), x.name, x.predicate))
    )
end

to_expr(x::PatSegment{typeof(alwaystrue)}) = 
    Expr(:..., Expr(:call, :~, x.name))

to_expr(x::PatSegment{T}) where {T <: Function} = 
    Expr(:..., Expr(:call, :~, Expr(:(::), x.name, nameof(T))))

to_expr(x::PatSegment{<:Type{T}}) where T = 
    Expr(:..., Expr(:call, :~, Expr(:(::), x.name, T)))

function to_expr(x::PatTerm) 
    pl = operation(x)
    similarterm(Expr(:call, :x), pl, map(to_expr, arguments(x)); exprhead=exprhead(x))
end



# include("rules/patterns.jl")
export AbstractPat
export PatVar
export PatTerm
export PatSegment
export patvars
export setdebrujin!
export isground
export UnsupportedPatternException


end
