module Patterns

using Metatheory: alwaystrue, maybe_quote_operation
using TermInterface
using Metatheory.VecExprModule

import Metatheory: to_expr

export Pat,
  PatternType, PAT_LITERAL, PAT_VARIABLE, PAT_SEGMENT, PAT_EXPR, pat_literal, pat_var, pat_expr, patvars, setdebrujin!

@enum PatternType PAT_LITERAL PAT_VARIABLE PAT_SEGMENT PAT_EXPR

mutable struct Pat
  type::PatternType
  isground::Bool
  idx::Int
  predicate::Function
  head
  head_hash::UInt
  name
  name_hash::UInt
  children::Vector{Pat}
  """
  Behaves like an e-node to not re-allocate memory when doing e-graph lookups and instantiation
  in case of cache hits in the e-graph hashcons
  """
  n::VecExpr
end


function pat_literal(val)::Pat
  h = hash(val)
  Pat(PAT_LITERAL, true, -1, alwaystrue, val, h, val, h, Pat[], v_new_literal(h))
end

function pat_var(type::PatternType, var::Symbol, idx::Int, predicate::Function)
  h = hash(var)
  Pat(type, false, idx, predicate, var, h, var, h, Pat[], VecExpr(Id[]))
end
pat_var(type::PatternType, var::Symbol, idx::Int) = pat_var(type, var, idx, alwaystrue)
pat_var(type::PatternType, var::Symbol) = pat_var(type, var, -1)


function pat_expr(iscall::Bool, op, qop, args::Vector{Pat})
  op_hash = hash(op)
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

  Pat(PAT_EXPR, all(x -> x.isground, args), -1, alwaystrue, op, op_hash, qop, qop_hash, args, n)
end

pat_expr(iscall, op, args::Vector{Pat}) = pat_expr(iscall, op, maybe_quote_operation(op), args)

function Base.:(==)(a::Pat, b::Pat)
  a.type === b.type || return false

  if a.type === PAT_LITERAL
    isequal(a.head, b.head)
  elseif a.type === PAT_VARIABLE || a.type === PAT_SEGMENT
    a.name === b.name && a.idx === b.idx
  elseif a.type === PAT_EXPR
    a.head_hash === b.head_hash && v_signature(a.n) === v_signature(b.n) && all(a.children .== b.children)
  end
end

# TODO consider p.n ?
Base.hash(p::Pat, h::UInt) =
  hash(p.type, hash(p.head, hash(p.name, hash(p.idx, hash(p.predicate, hash(p.children, h))))))

TermInterface.arity(p::Pat) = p.type === PAT_EXPR ? length(p.children) : 0
TermInterface.isexpr(p::Pat) = p.type === PAT_EXPR
TermInterface.head(p::Pat) = p.head
TermInterface.operation(p::Pat) = p.head
TermInterface.children(p::Pat) = p.children
TermInterface.arguments(p::Pat) = p.children
TermInterface.iscall(p::Pat) = v_iscall(p.n)

function TermInterface.maketerm(::Type{Pat}, operation, arguments, metadata)
  iscall = isnothing(metadata) ? true : metadata.iscall
  pat_expr(iscall, operation, arguments...)
end


"""
Collects pattern variables appearing in a pattern into a vector of symbols
"""
function patvars!(p::Pat, s::Vector{Symbol})
  if p.type === PAT_VARIABLE || p.type === PAT_SEGMENT
    push!(s, p.name)
  elseif p.type === PAT_EXPR
    p.head isa Pat && patvars!(operation(p), s)
    for pp in arguments(p)
      patvars!(pp, s)
    end
  end
  s
end
patvars(p::Pat) = unique!(patvars!(p, Symbol[]))



function setdebrujin!(p::Pat, pvars::Vector{Symbol})
  if p.type === PAT_EXPR
    p.head isa Pat && setdebrujin!(p.head, pvars)
    for pp in p.children
      setdebrujin!(pp, pvars)
    end
  elseif p.type === PAT_VARIABLE || p.type === PAT_SEGMENT
    p.idx = findfirst((==)(p.name), pvars)
  end
end

function _wrap_predicate(p::Pat)
  p.predicate === alwaystrue && return p.name
  if p.predicate isa Base.Fix2{typeof(isa),<:Type}
    Expr(:(::), p.name, p.predicate.x)
  else
    Expr(:(::), p.name, p.predicate)
  end
end

function to_expr(p::Pat)
  if p.type === PAT_LITERAL
    p.head
  elseif p.type === PAT_VARIABLE
    Expr(:call, :~, _wrap_predicate(p))
  elseif p.type === PAT_SEGMENT
    Expr(:..., Expr(:call, :~, _wrap_predicate(p)))
  elseif p.type === PAT_EXPR
    if iscall(p)
      maketerm(Expr, :call, [p.name; to_expr.(p.children)], nothing)
    else
      maketerm(Expr, operation(p), to_expr.(p.children), nothing)
    end
  end
end


Base.show(io::IO, p::Pat) = print(io, to_expr(p))


end
