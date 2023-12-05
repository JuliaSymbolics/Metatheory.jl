module Patterns

using Metatheory: binarize, cleanast, alwaystrue
using AutoHashEquals
using TermInterface


"""
Abstract type representing a pattern used in all the various pattern matching backends. 
"""
abstract type AbstractPat end

struct PatHead
  head
end
TermInterface.head_symbol(p::PatHead) = p.head

PatHead(p::PatHead) = error("recursive!")

struct UnsupportedPatternException <: Exception
  p::AbstractPat
end

Base.showerror(io::IO, e::UnsupportedPatternException) = print(io, "Pattern ", e.p, " is unsupported in this context")


Base.:(==)(a::AbstractPat, b::AbstractPat) = false
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
  predicate_code
end
Base.:(==)(a::PatVar, b::PatVar) = a.idx == b.idx
PatVar(var) = PatVar(var, -1, alwaystrue, nothing)
PatVar(var, i) = PatVar(var, i, alwaystrue, nothing)

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
  predicate_code
end

PatSegment(v) = PatSegment(v, -1, alwaystrue, nothing)
PatSegment(v, i) = PatSegment(v, i, alwaystrue, nothing)


"""
Term patterns will match on terms of the same `arity` and with the same function
symbol `operation` and expression head `head.head`.
"""
struct PatTerm <: AbstractPat
  head::PatHead
  tail::Vector
  PatTerm(h, t::Vector) = new(h, t)
end
PatTerm(eh, op) = PatTerm(eh, [op])
PatTerm(eh, tail...) = PatTerm(eh, collect(tail))
TermInterface.istree(::PatTerm) = true
TermInterface.head(p::PatTerm)::PatHead = p.head
TermInterface.tail(p::PatTerm) = p.tail
function TermInterface.operation(p::PatTerm)
  hs = head_symbol(head(p))
  hs == :call ? first(p.tail) : hs
end
function TermInterface.arguments(p::PatTerm)
  hs = head_symbol(head(p))
  hs == :call ? p.tail[2:end] : p.tail
end
TermInterface.arity(p::PatTerm) = length(arguments(p))
TermInterface.metadata(p::PatTerm) = nothing

TermInterface.maketerm(head::PatHead, tail; type = Any, metadata = nothing) = PatTerm(head, tail...)

isground(p::PatTerm) = all(isground, p.tail)


# ==============================================
# ================== PATTERN VARIABLES =========
# ==============================================

"""
Collects pattern variables appearing in a pattern into a vector of symbols
"""
patvars(p::PatVar, s) = push!(s, p.name)
patvars(p::PatSegment, s) = push!(s, p.name)
patvars(p::PatTerm, s) = (patvars(operation(p), s); foreach(x -> patvars(x, s), arguments(p)); s)
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
  foreach(x -> setdebrujin!(x, pvars), p.tail)
end


to_expr(x) = x
to_expr(x::PatVar{T}) where {T} = Expr(:call, :~, Expr(:(::), x.name, x.predicate_code))
to_expr(x::PatSegment{T}) where {T<:Function} = Expr(:..., Expr(:call, :~, Expr(:(::), x.name, x.predicate_code)))
to_expr(x::PatVar{typeof(alwaystrue)}) = Expr(:call, :~, x.name)
to_expr(x::PatSegment{typeof(alwaystrue)}) = Expr(:..., Expr(:call, :~, x.name))
to_expr(x::PatTerm) = maketerm(ExprHead(head_symbol(head(x))), to_expr.(tail(x)))

Base.show(io::IO, pat::AbstractPat) = print(io, to_expr(pat))


# include("rules/patterns.jl")
export AbstractPat
export PatHead
export PatVar
export PatTerm
export PatSegment
export patvars
export setdebrujin!
export isground
export UnsupportedPatternException


end
