using DataStructures
using Base.Meta
using StaticArrays
using AutoHashEquals

@auto_hash_equals struct EClass
    id::Int64
end


@auto_hash_equals struct ENode
    head::Any
    iscall::Bool
    args::MVector{T, Int64} where T
    sourcetype::Type
    metadata::Any
end

ariety(n::ENode) = length(n.args)

iscall(e::ENode) = error()
getfunsym(e::ENode) = error()
setfunsym!(e::ENode, s) = error()
getfunargs(e::ENode) = error()

function setfunargs!(e::ENode, args::Vector)
    error()
end

istree(e::ENode) = error()

struct EClass
    id::Int64
end

function ENode(e::Expr)
    args = map(x->x.id, getfunargs(e))
    static_args = MVector{length(args), Int64}(args...)
    ENode(getfunsym(e), iscall(e), static_args, Expr, nothing)
end

function ENode(a)
    ENode(a, false, MVector{0, Int64}(), typeof(a), nothing)
end

ENode(a::ENode) =
    error("constructor of ENode called on enode. This should never happen")
