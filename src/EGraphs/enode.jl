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

function ENode(e)
    args = map(x -> ( (@assert x isa EClass); x.id), getargs(e))
    static_args = MVector{length(args), Int64}(args...)
    ENode(gethead(e), static_args, typeof(e), getmetadata(e))
end

ENode(a::ENode) =
    error("constructor of ENode called on enode. This should never happen")
