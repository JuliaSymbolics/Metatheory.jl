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
  v_unset_hash!

const Id = UInt64

"""
    const VecExpr = Vector{Id}

An e-node is a `Vector{ID}` where:
* Position 1 stores the hash of the `VecExpr`.
* Position 2 stores the bit flags (`istree` or `iscall`).
* Position 3 stores the index of the `head` (if `istree`) or value in the e-graph constants.
* The rest of the positions store the e-class ids of the children nodes.
"""
const VecExpr = Vector{Id}

const VECEXPR_FLAG_ISTREE = 0x01
const VECEXPR_FLAG_ISCALL = 0x10
const VECEXPR_META_LENGTH = 3

@inline v_flags(n::VecExpr)::Id = @inbounds n[2]
@inline v_unset_flags!(n::VecExpr) = @inbounds (n[2] = 0)
@inline v_check_flags(n::VecExpr, flag::Id)::Bool = !iszero(v_flags(n) & flags)
@inline v_set_flag!(n::VecExpr, flag)::Id = @inbounds (n[2] = n[2] | flag)

@inline v_isexpr(n::VecExpr)::Bool = !iszero(v_flags(n) & VECEXPR_FLAG_ISTREE)
@inline v_iscall(n::VecExpr)::Bool = !iszero(v_flags(n) & VECEXPR_FLAG_ISCALL)

@inline v_arity(n::VecExpr)::Int = length(n) - VECEXPR_META_LENGTH

"""
Compute the hash of a `VecExpr` and store it as the first element.
"""
@inline function v_hash!(n::VecExpr)::Id
  if iszero(n[1])
    n[1] = hash(@view n[2:end])
  else
    # h = hash(@view n[2:end])
    # @assert h == n[1]
    n[1]
  end
end

@inline v_hash(n::VecExpr)::Id = @inbounds n[1]
@inline v_unset_hash!(n::VecExpr)::Id = @inbounds (n[1] = Id(0))

@inline v_children(n::VecExpr) = @view n[(VECEXPR_META_LENGTH + 1):end]
@inline v_head(n::VecExpr)::Id = @inbounds n[VECEXPR_META_LENGTH]
@inline v_set_head!(n::VecExpr, h::Id) = @inbounds (n[3] = h)

@inline function v_new(len::Int)::VecExpr
  n = Vector{Id}(undef, len + VECEXPR_META_LENGTH)
  v_unset_hash!(n)
  v_unset_flags!(n)
  n
end

@inline v_children_range(n::VecExpr) = ((VECEXPR_META_LENGTH + 1):length(n))


end
