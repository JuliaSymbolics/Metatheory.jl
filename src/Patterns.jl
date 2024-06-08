module Patterns

using Metatheory: cleanast, alwaystrue, maybe_quote_operation
using AutoHashEquals
using TermInterface
using Metatheory.VecExprModule

import Metatheory: to_expr

export AbstractPat, PatLiteral, PatVar, PatExpr, PatSegment, patvars, setdebrujin!, isground, constants

"""
Abstract type representing a pattern used in all the various pattern matching backends. 
"""
abstract type AbstractPat end


Base.:(==)(a::AbstractPat, b::AbstractPat) = false
TermInterface.arity(p::AbstractPat) = 0
"""
A ground pattern contains no pattern variables and 
only literal values to match.
"""
isground(p::AbstractPat) = false

struct PatLiteral <: AbstractPat
  value
  n::VecExpr
  PatLiteral(val) = new(val, Id[0, 0, 0, hash(val)])
end

PatLiteral(p::AbstractPat) = throw(DomainError(p, "Cannot construct a pattern literal of another pattern object."))

isground(x::PatLiteral) = true # literals


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
mutable struct PatVar{P<:Union{Function,Type}} <: AbstractPat
  name::Symbol
  idx::Int
  predicate::P
end
Base.:(==)(a::PatVar, b::PatVar) = a.idx == b.idx
PatVar(var) = PatVar(var, -1, alwaystrue)
PatVar(var, i) = PatVar(var, i, alwaystrue)

"""
If you want to match a variable number of subexpressions at once, you will need
a **segment pattern**. 
A segment pattern represents a vector of subexpressions matched. 
You can attach a predicate `g` to a segment variable. In the case of segment variables `g` gets a vector of 0 or more 
expressions and must return a boolean value. 
"""
mutable struct PatSegment{P<:Union{Function,Type}} <: AbstractPat
  name::Symbol
  idx::Int
  predicate::P
end

PatSegment(v) = PatSegment(v, -1, alwaystrue)
PatSegment(v, i) = PatSegment(v, i, alwaystrue)


"""
Term patterns will match on terms of the same `arity` and with the same `operation`.
"""
struct PatExpr <: AbstractPat
  head
  head_hash::UInt
  quoted_head
  quoted_head_hash::UInt
  children::Vector{AbstractPat}
  isground::Bool
  """
  Behaves like an e-node to not re-allocate memory when doing e-graph lookups and instantiation 
  in case of cache hits in the e-graph hashcons
  """
  n::VecExpr
  function PatExpr(iscall, op, args::Vector)
    op_hash = hash(op)
    # Should call `nameof` on op if Function or DataType. Identity otherwise
    qop = maybe_quote_operation(op)
    qop_hash = hash(qop)
    ar = length(args)
    signature = hash(qop, hash(ar))

    n = v_new(ar)
    v_set_flag!(n, VECEXPR_FLAG_ISTREE)
    iscall && v_set_flag!(n, VECEXPR_FLAG_ISCALL)
    v_set_head!(n, op_hash)
    v_set_signature!(n, signature)

    for i in v_children_range(n)
      @inbounds n[i] = 0
    end

    new(op, op_hash, qop, qop_hash, args, all(isground, args), n)
  end
end

isground(p::PatExpr)::Bool = p.isground

TermInterface.isexpr(::PatExpr) = true
TermInterface.head(p::PatExpr) = p.head
TermInterface.operation(p::PatExpr) = p.head
TermInterface.children(p::PatExpr) = p.children
TermInterface.arguments(p::PatExpr) = p.children
TermInterface.iscall(p::PatExpr) = v_iscall(p.n)

TermInterface.arity(p::PatExpr) = length(p.children)

function TermInterface.maketerm(::Type{PatExpr}, operation, arguments, metadata)
  iscall = isnothing(metadata) ? true : metadata.iscall
  PatExpr(iscall, operation, arguments...)
end

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
setdebrujin!(::Any, pvars) = nothing

function setdebrujin!(p::PatExpr, pvars)
  setdebrujin!(operation(p), pvars)
  foreach(x -> setdebrujin!(x, pvars), p.children)
end

to_expr(x::PatLiteral) = x.value
to_expr(x::PatVar{T}) where {T} = Expr(:call, :~, Expr(:(::), x.name, x.predicate))
to_expr(x::PatSegment{T}) where {T<:Function} = Expr(:..., Expr(:call, :~, Expr(:(::), x.name, x.predicate)))
to_expr(x::PatVar{typeof(alwaystrue)}) = Expr(:call, :~, x.name)
to_expr(x::PatSegment{typeof(alwaystrue)}) = Expr(:..., Expr(:call, :~, x.name))
function to_expr(x::PatExpr)
  if iscall(x)
    op = operation(x)
    op_name = op isa Union{Function,DataType} ? nameof(op) : op
    maketerm(Expr, :call, [op_name; to_expr.(arguments(x))], nothing)
  else
    maketerm(Expr, operation(x), to_expr.(arguments(x)), nothing)
  end
end

Base.show(io::IO, pat::AbstractPat) = print(io, to_expr(pat))


end
