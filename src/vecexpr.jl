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
VecExpr vector syntax:

An e-node is a vector of `Id`

Position 1 stores the hash
Position 2 stores the bit flags (is tree, is function call)
Position 3 stores the index of the head (if is tree) or value in the e-graph constants
Rest of positions store the e-class ids of the children
"""

const VecExpr = Vector{Id}

const VECEXPR_FLAG_ISTREE = 0x01
const VECEXPR_FLAG_ISCALL = 0x10
const VECEXPR_META_LENGTH = 3

@inline v_flags(n::VecExpr)::Id = n[2]
@inline v_unset_flags!(n::VecExpr) = (n[2] = 0)
@inline v_check_flags(n::VecExpr, flag::Id)::Bool = !iszero(v_flags(n) & flags)
@inline v_set_flag!(n::VecExpr, flag)::Id = (n[2] = n[2] | flag)

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

@inline v_hash(n::VecExpr)::Id = n[1]
@inline v_unset_hash!(n::VecExpr)::Id = (n[1] = Id(0))

@inline v_children(n::VecExpr) = @view n[(VECEXPR_META_LENGTH + 1):end]
@inline v_head(n::VecExpr)::Id = n[VECEXPR_META_LENGTH]
@inline v_set_head!(n::VecExpr, h::Id) = (n[3] = h)

@inline function v_new(len::Int)::VecExpr
  n = Vector{Id}(undef, len + VECEXPR_META_LENGTH)
  v_unset_hash!(n)
  v_unset_flags!(n)
  n
end

@inline v_children_range(n::VecExpr) = ((VECEXPR_META_LENGTH + 1):length(n))


end