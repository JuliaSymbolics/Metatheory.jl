using DataStructures
using Base.Meta

import Base.ImmutableDict

const EClassId = Int64

mutable struct ENode{T}
    exprhead::Union{Symbol, Nothing}
    operation::Any
    args::Vector{EClassId}
    hash::Ref{UInt} # hash cache
end

# function ENode{T}(head, c_ids::AbstractVector{EClassId}, ps=[], pt=[], age=0) where {T}
function ENode{T}(exprhead, operation, c_ids) where {T}
    ENode{T}(exprhead, operation, c_ids, Ref{UInt}(0))
end

ENode(a) = ENode{typeof(a)}(nothing, a, [])


ENode(a::ENode) =
    error("constructor of ENode called on enode. This should never happen")

function Base.:(==)(a::ENode, b::ENode)
    isequal(a.args, b.args) && 
    isequal(a.exprhead, b.exprhead) && isequal(a.operation, b.operation)
end

# This optimization comes from SymbolicUtils
# The hash of an enode is cached to avoid recomputing it.
# Shaves off a lot of time in accessing dictionaries with ENodes as keys.
function Base.hash(t::ENode{T}, salt::UInt) where {T}
    !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
    h = t.hash[]
    !iszero(h) && return h
    h′ = hash(t.args,  hash(t.exprhead, hash(t.operation, hash(T, salt))))
    t.hash[] = h′
    return h′
end

TermInterface.exprhead(n::ENode) = n.exprhead
TermInterface.operation(n::ENode) = n.operation 
TermInterface.arguments(n::ENode) = n.args 
TermInterface.arity(n::ENode) = length(n.args)
# TermInterface.metadata(n::ENode) = n.metadata

termtype(x::ENode{T}) where T = T

function toexpr(n::ENode)
    eh = exprhead(n)
    if isnothing(eh)
        return operation(n) # n is a constant enode
    end
    similarterm(Expr, operation(n), map(i -> Symbol(i, "ₑ"), arguments(n)); exprhead=exprhead(n))
end



function Base.show(io::IO, x::ENode{T}) where {T}
    print(io, "ENode{$T}(", toexpr(x), ")")
end
