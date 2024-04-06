module Patterns

using Metatheory: cleanast, alwaystrue
using AutoHashEquals
using TermInterface

import Metatheory: to_expr

"""
Abstract type representing a pattern used in all the various pattern matching backends. 
"""
abstract type AbstractPat end

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
Term patterns will match on terms of the same `arity` and with the same `operation`.
"""
struct PatExpr <: AbstractPat
  iscall::Bool
  head
  head_hash::UInt
  children::Vector
  isground::Bool
  PatExpr(iscall, op, args::Vector) = new(iscall, op, hash(op), args, all(isground, args))
end
PatExpr(iscall, op, children...) = PatExpr(iscall, op, collect(children))

isground(p::PatExpr)::Bool = p.isground

TermInterface.isexpr(::PatExpr) = true
TermInterface.head(p::PatExpr) = p.head
TermInterface.operation(p::PatExpr) = p.head
TermInterface.children(p::PatExpr) = p.children
TermInterface.arguments(p::PatExpr) = p.children
TermInterface.iscall(p::PatExpr) = p.iscall

TermInterface.arity(p::PatExpr) = length(p.children)

TermInterface.maketerm(::Type{PatExpr}, operation, arguments, type = Any, metadata = (iscall = true,)) =
  PatExpr(iscall, operation, children...)

# ---------------------
# # Pattern Variables.

"""
Collects pattern variables appearing in a pattern into a vector of symbols
"""
patvars(p::PatVar, s) = push!(s, p.name)
patvars(p::PatSegment, s) = push!(s, p.name)
patvars(p::PatExpr, s) = (patvars(operation(p), s); foreach(x -> patvars(x, s), arguments(p)); s)
patvars(::Any, s) = s
patvars(p) = unique!(patvars(p, Symbol[]))


# ---------------------
# # Debrujin Indexing.


function setdebrujin!(p::Union{PatVar,PatSegment}, pvars)
  p.idx = findfirst((==)(p.name), pvars)
end

# literal case
setdebrujin!(p, pvars) = nothing

function setdebrujin!(p::PatExpr, pvars)
  setdebrujin!(operation(p), pvars)
  foreach(x -> setdebrujin!(x, pvars), p.children)
end


to_expr(x) = x
to_expr(x::PatVar{T}) where {T} = Expr(:call, :~, Expr(:(::), x.name, x.predicate_code))
to_expr(x::PatSegment{T}) where {T<:Function} = Expr(:..., Expr(:call, :~, Expr(:(::), x.name, x.predicate_code)))
to_expr(x::PatVar{typeof(alwaystrue)}) = Expr(:call, :~, x.name)
to_expr(x::PatSegment{typeof(alwaystrue)}) = Expr(:..., Expr(:call, :~, x.name))
function to_expr(x::PatExpr)
  if iscall(x)
    op = operation(x)
    op_name = op isa Union{Function,DataType} ? nameof(op) : op
    maketerm(Expr, :call, [op_name; to_expr.(arguments(x))])
  else
    maketerm(Expr, operation(x), to_expr.(arguments(x)))
  end
end

Base.show(io::IO, pat::AbstractPat) = print(io, to_expr(pat))


# include("rules/patterns.jl")
export AbstractPat
export PatVar
export PatExpr
export PatSegment
export patvars
export setdebrujin!
export isground
export UnsupportedPatternException


end
