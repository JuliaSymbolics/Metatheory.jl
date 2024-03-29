module VecExprModule

export Id,
  VecExpr,
  VECEXPR_FLAG_ISEXPR,
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

An e-node is a `Vector{Id}` where:
* Position 1 stores the hash of the `VecExpr`.
* Position 2 stores the bit flags (`isexpr` or `iscall`).
* Position 3 stores the index of the `head` (if `isexpr`) or value in the e-graph constants.
* The rest of the positions store the e-class ids of the children nodes.
"""
const VecExpr = Vector{Id}

const VECEXPR_FLAG_ISEXPR = 0x001
const VECEXPR_FLAG_ISCALL = 0x010
const VECEXPR_FLAG_HASTYPE = 0x100
const VECEXPR_META_LENGTH = 3

@inline v_flags(n::VecExpr)::Id = @inbounds n[2]
@inline v_unset_flags!(n::VecExpr) = @inbounds (n[2] = 0)
@inline v_check_flags(n::VecExpr, flags::Id)::Bool = !iszero(v_flags(n) & flags)
@inline v_set_flag!(n::VecExpr, flag)::Id = @inbounds (n[2] = n[2] | flag)

"Returns `true` if the expression represented by the e-node satisfies `TermInterface.isexpr`."
@inline v_isexpr(n::VecExpr)::Bool = !iszero(v_flags(n) & VECEXPR_FLAG_ISEXPR)

"Returns `true` if the expression represented by the e-node satisfies `TermInterface.iscall`."
@inline v_iscall(n::VecExpr)::Bool = !iszero(v_flags(n) & VECEXPR_FLAG_ISCALL)

"""
Returns `true` iff last argument of the expression represented 
by the e-node is the `type` argument to `TermInterface.maketerm` (typed ASTs).
"""
@inline v_has_symtype(n::VecExpr)::Bool = !iszero(v_flags(n) & VECEXPR_FLAG_HASTYPE)

"If `v_has_symtype` is true, use this to get the `TermInterface.symtype` of the represented expression."
@inline v_symtype(n::VecExpr)::Bool = @inbounds n[end]

"If `v_has_symtype` is true, use this to get the `TermInterface.symtype` of the represented expression."
@inline function v_set_symtype!(n::VecExpr, symtype::Id)::Bool
  v_set_flag!(n, VECEXPR_FLAG_HASTYPE)
  @inbounds n[end] = symtype
end

"""Number of children in the e-node."""
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

"The hash of the e-node."
@inline v_hash(n::VecExpr)::Id = @inbounds n[1]

"Set e-node hash to zero."
@inline v_unset_hash!(n::VecExpr)::Id = @inbounds (n[1] = Id(0))

"E-class IDs of the children of the e-node."
@inline v_children(n::VecExpr) = @view n[v_children_range(n)]

"The constant ID of the operation of the e-node, or the e-node ."
@inline v_head(n::VecExpr)::Id = @inbounds n[VECEXPR_META_LENGTH]

"Update the E-Node operation ID."
@inline v_set_head!(n::VecExpr, h::Id) = @inbounds (n[3] = h)

"""Construct a new, empty `VecExpr` with `len` children."""
@inline function v_new(len::Int)::VecExpr
  n = Vector{Id}(undef, len + VECEXPR_META_LENGTH)
  v_unset_hash!(n)
  v_unset_flags!(n)
  n
end

@inline v_children_range(n::VecExpr) = let l = length(n) 
  ((VECEXPR_META_LENGTH + 1):(v_has_symtype(n) ? l+1 : l))
end


end
