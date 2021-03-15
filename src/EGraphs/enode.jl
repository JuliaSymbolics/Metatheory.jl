using DataStructures
using Base.Meta
using AutoHashEquals

import Base.ImmutableDict

@auto_hash_equals struct EClass
    id::Int64
end


@auto_hash_equals struct ENode{X}
    head::Any
    args::Vector{Int64}
    metadata::Union{Nothing, NamedTuple}
end

ariety(n::ENode) = length(n.args)

function ENode(e, c_ids::AbstractVector{Int64})
    # @assert length(getargs(e)) == length(c_ids)
    # static_args = MVector{length(c_ids), Int64}(c_ids...)
    ENode{typeof(e)}(gethead(e), c_ids, getmetadata(e))
end

ENode(e) = ENode(e, Int64[])

ENode(a::ENode) =
    error("constructor of ENode called on enode. This should never happen")
