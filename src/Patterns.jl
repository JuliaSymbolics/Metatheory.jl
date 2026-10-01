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
Term patterns will match
on terms of the same `arity` and with the same 
function symbol `operation` and expression head `exprhead`.
"""
struct PatTerm <: AbstractPat
  exprhead::Any
  operation::Any
  args::Vector
  PatTerm(eh, op, args) = new(eh, op, args) #Ref{UInt}(0))
end
TermInterface.istree(::PatTerm) = true
TermInterface.exprhead(e::PatTerm) = e.exprhead
TermInterface.operation(p::PatTerm) = p.operation
TermInterface.arguments(p::PatTerm) = p.args
TermInterface.arity(p::PatTerm) = length(arguments(p))
TermInterface.metadata(p::PatTerm) = nothing

function TermInterface.similarterm(x::PatTerm, head, args, symtype = nothing; metadata = nothing, exprhead = :call)
  PatTerm(exprhead, head, args)
end

isground(p::PatTerm) = all(isground, p.args)


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
  foreach(x -> setdebrujin!(x, pvars), p.args)
end


# ==============================================
# ====== PATTERN VARIABLE PREDICATE PROPAGATION
# ==============================================
# Matchers only check a variable's predicate on the first (unbound) occurrence.
# Later occurrences only test equality with the existing binding. If a non-trivial
# predicate is attached to a later occurrence only (e.g. `a / a::f`), it would be
# ignored. After de Bruijn indexing, propagate one predicate per idx to every
# occurrence, and reject conflicting non-trivial predicates.
# See JuliaSymbolics/Metatheory.jl#246.

is_trivial_predicate(pred) = pred === alwaystrue

function collect_var_predicates!(p::Union{PatVar,PatSegment}, table::Dict{Int,Any})
  is_trivial_predicate(p.predicate) && return
  idx = p.idx
  if haskey(table, idx)
    prev = table[idx]
    if prev.predicate !== p.predicate
      throw(ArgumentError(
        "conflicting predicates for pattern variable $(p.name) " *
        "(de Bruijn index $idx): $(prev.predicate_code) vs $(p.predicate_code)",
      ))
    end
  else
    table[idx] = (; predicate = p.predicate, predicate_code = p.predicate_code)
  end
  return
end

collect_var_predicates!(p::PatTerm, table::Dict{Int,Any}) =
  (collect_var_predicates!(operation(p), table); foreach(x -> collect_var_predicates!(x, table), arguments(p)))
collect_var_predicates!(::Any, ::Dict{Int,Any}) = nothing

function apply_var_predicates(p::PatVar, table::Dict{Int,Any})
  haskey(table, p.idx) || return p
  info = table[p.idx]
  p.predicate === info.predicate && return p
  return PatVar(p.name, p.idx, info.predicate, info.predicate_code)
end

function apply_var_predicates(p::PatSegment, table::Dict{Int,Any})
  haskey(table, p.idx) || return p
  info = table[p.idx]
  p.predicate === info.predicate && return p
  return PatSegment(p.name, p.idx, info.predicate, info.predicate_code)
end

function apply_var_predicates(p::PatTerm, table::Dict{Int,Any})
  new_op = apply_var_predicates(operation(p), table)
  for i in eachindex(p.args)
    p.args[i] = apply_var_predicates(p.args[i], table)
  end
  new_op === operation(p) && return p
  return PatTerm(exprhead(p), new_op, p.args)
end

apply_var_predicates(p, ::Dict{Int,Any}) = p

"""
    propagate_pattern_predicates!(p)

After [`setdebrujin!`](@ref), ensure every occurrence of a pattern variable carries
the same predicate. Non-trivial predicates on later occurrences are copied to
earlier ones so matchers (which only check predicates when binding) observe them.
Throws `ArgumentError` if two occurrences of the same variable have different
non-trivial predicates.
"""
function propagate_pattern_predicates!(p)
  table = Dict{Int,Any}()
  collect_var_predicates!(p, table)
  isempty(table) && return p
  return apply_var_predicates(p, table)
end


to_expr(x) = x
to_expr(x::PatVar{T}) where {T} = Expr(:call, :~, Expr(:(::), x.name, x.predicate_code))
to_expr(x::PatSegment{T}) where {T<:Function} = Expr(:..., Expr(:call, :~, Expr(:(::), x.name, x.predicate_code)))
to_expr(x::PatVar{typeof(alwaystrue)}) = Expr(:call, :~, x.name)
to_expr(x::PatSegment{typeof(alwaystrue)}) = Expr(:..., Expr(:call, :~, x.name))
to_expr(x::PatTerm) = similarterm(Expr(:call, :x), operation(x), map(to_expr, arguments(x)); exprhead = exprhead(x))

Base.show(io::IO, pat::AbstractPat) = print(io, to_expr(pat))


# include("rules/patterns.jl")
export AbstractPat
export PatVar
export PatTerm
export PatSegment
export patvars
export setdebrujin!
export propagate_pattern_predicates!
export isground
export UnsupportedPatternException


end
