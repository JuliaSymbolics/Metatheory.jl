using DataStructures
using Base.Meta
using StaticArrays
using AutoHashEquals

@auto_hash_equals struct EClass
    id::Int64
end


@auto_hash_equals struct ENode
    head::Any
    args::MVector{T, Int64} where T
    sourcetype::Type
    metadata::Any
end

ariety(n::ENode) = length(n.args)

struct EClass
    id::Int64
end

function ENode(e, c_ids::AbstractVector{Int64})
    @assert length(getargs(e)) == length(c_ids)
    static_args = MVector{length(c_ids), Int64}(c_ids...)
    ENode(gethead(e), static_args, typeof(e), getmetadata(e))
end

ENode(e) = ENode(e, Int64[])

ENode(a::ENode) =
    error("constructor of ENode called on enode. This should never happen")
