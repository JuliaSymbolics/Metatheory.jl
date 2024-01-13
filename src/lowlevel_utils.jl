
const Id = UInt64

"""
E-Node vector syntax:

An e-node is a vector of UInt64

Position 1 stores the hash
Position 2 stores the bit flags (is tree, is function call)
Position 3 stores the index of the head (if is tree) or value in the e-graph constants
Rest of positions store the e-class ids of the children
"""

const ENode = Vector{Id}

const ENODE_FLAG_ISTREE = 0x01
const ENODE_FLAG_ISCALL = 0x10
const ENODE_META_LENGTH = 3

@inline enode_flags(n::ENode)::UInt64 = n[2]
@inline enode_istree(n::ENode)::Bool = !iszero(enode_flags(n) & ENODE_FLAG_ISTREE)
@inline enode_is_function_call(n::ENode)::Bool = !iszero(enode_flags(n) & ENODE_FLAG_ISCALL)
@inline enode_arity(n::ENode)::Int = length(n) - ENODE_META_LENGTH

@inline function enode_hash!(n::ENode)::UInt64
  if iszero(n[1])
    n[1] = hash(@view n[2:end])
  else
    h = hash(@view n[2:end])
    @assert h == n[1]
    n[1]
  end
end

@inline enode_hash(n::ENode)::UInt64 = n[1]

@inline enode_children(n) = @view n[(ENODE_META_LENGTH + 1):end]
@inline enode_head(n)::Id = n[ENODE_META_LENGTH]

