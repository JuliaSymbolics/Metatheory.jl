module VecExprModule

export Id,
  VecExpr,
  VECEXPR_FLAG_ISTREE,
  VECEXPR_FLAG_ISCALL,
  VECEXPR_META_LENGTH,
  v_new,
  v_flags,
  v_unset_flags!,
  v_check_flags,
  v_set_flag!,
  v_isexpr,
  v_iscall,
  v_head,
  v_set_head!,
  v_children,
  v_children_range,
  v_arity,
  v_hash!,
  v_hash,
  v_unset_hash!,
  v_signature,
  v_set_signature!,
  v_pair,
  v_pair_first,
  v_pair_last

const Id = UInt64

"""
    struct VecExpr
      data::Vector{Id}
    end

An e-node is represented by `Vector{Id}` where:
* Position 1 stores the hash of the `VecExpr`.
* Position 2 stores the bit flags (`isexpr` or `iscall`).
* Position 3 stores the signature
* Position 4 stores the hash of the `head` (if `isexpr`) or node value in the e-graph constants.
* The rest of the positions store the e-class ids of the children nodes.

The expression is represented as an array of integers to improve performance.
The hash value for the VecExpr is cached in the first position for faster lookup performance in dictionaries.
"""
struct VecExpr
  data::Vector{Id}
end

const VECEXPR_FLAG_ISTREE = 0x01
const VECEXPR_FLAG_ISCALL = 0x10
const VECEXPR_META_LENGTH = 4

@inline v_flags(n::VecExpr)::Id = @inbounds n.data[2]
@inline v_unset_flags!(n::VecExpr) = @inbounds (n.data[2] = 0)
@inline v_check_flags(n::VecExpr, flag::Id)::Bool = !iszero(v_flags(n) & flags)
@inline v_set_flag!(n::VecExpr, flag)::Id = @inbounds (n.data[2] = n.data[2] | flag)

"""Returns `true` if the e-node ID points to a an expression tree."""
@inline v_isexpr(n::VecExpr)::Bool = !iszero(v_flags(n) & VECEXPR_FLAG_ISTREE)

"""Returns `true` if the e-node ID points to a function call."""
@inline v_iscall(n::VecExpr)::Bool = !iszero(v_flags(n) & VECEXPR_FLAG_ISCALL)

"""Number of children in the e-node."""
@inline v_arity(n::VecExpr)::Int = length(n.data) - VECEXPR_META_LENGTH

"""
Compute the hash of a `VecExpr` and store it as the first element.
"""
@inline function v_hash!(n::VecExpr)::Id
  if iszero(n.data[1])
    n.data[1] = hash(@view n.data[2:end])
  else
    # h = hash(@view n[2:end])
    # @assert h == n[1]
    n.data[1]
  end
end

"""The hash of the e-node."""
@inline v_hash(n::VecExpr)::Id = @inbounds n.data[1]
Base.hash(n::VecExpr, h::UInt) = hash(v_hash(n), h) # IdKey not necessary here
Base.:(==)(a::VecExpr, b::VecExpr) = (@view a.data[2:end]) == (@view b.data[2:end])

"""Set e-node hash to zero."""
@inline v_unset_hash!(n::VecExpr)::Id = @inbounds (n.data[1] = Id(0))

"""E-class IDs of the children of the e-node."""
@inline v_children(n::VecExpr) = @view n.data[(VECEXPR_META_LENGTH + 1):end]

@inline v_signature(n::VecExpr)::Id = @inbounds n.data[3]

@inline v_set_signature!(n::VecExpr, sig::Id) = @inbounds (n.data[3] = sig)

"The constant ID of the operation of the e-node, or the e-node ."
@inline v_head(n::VecExpr)::Id = @inbounds n.data[VECEXPR_META_LENGTH]

"Update the E-Node operation ID."
@inline v_set_head!(n::VecExpr, h::Id) = @inbounds (n.data[VECEXPR_META_LENGTH] = h)

"""Construct a new, empty `VecExpr` with `len` children."""
@inline function v_new(len::Int)::VecExpr
  n = VecExpr(Vector{Id}(undef, len + VECEXPR_META_LENGTH))
  v_unset_hash!(n)
  v_unset_flags!(n)
  n
end

@inline v_children_range(n::VecExpr) = ((VECEXPR_META_LENGTH + 1):length(n.data))


v_pair(a::UInt64, b::UInt64) = UInt128(a) << 64 | b
v_pair_first(p::UInt128)::UInt64 = UInt64(p >> 64)
v_pair_last(p::UInt128)::UInt64 = UInt64(p & 0xffffffffffffffff)

@inline Base.length(n::VecExpr) = length(n.data)
@inline Base.getindex(n::VecExpr, i) = n.data[i]
@inline Base.setindex!(n::VecExpr, val, i) = n.data[i] = val
@inline Base.copy(n::VecExpr) = VecExpr(copy(n.data))
@inline Base.lastindex(n::VecExpr) = lastindex(n.data)
@inline Base.firstindex(n::VecExpr) = firstindex(n.data)

Base.isless(a::VecExpr,b::VecExpr) = isless(a.data,b.data)

end
