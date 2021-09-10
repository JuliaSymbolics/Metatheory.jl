using DataStructures
using Base.Meta

import Base.ImmutableDict

const EClassId = Int64

abstract type AbstractENode{T} end

mutable struct ENodeTerm{T} <: AbstractENode{T}
    exprhead::Union{Symbol, Nothing}
    operation::Any
    args::Vector{EClassId}
    hash::Ref{UInt} # hash cache
end

function ENodeTerm{T}(exprhead, operation, c_ids) where {T}
    ENodeTerm{T}(exprhead, operation, c_ids, Ref{UInt}(0))
end


function Base.:(==)(a::ENodeTerm, b::ENodeTerm)
    isequal(a.args, b.args) && 
    isequal(a.exprhead, b.exprhead) && isequal(a.operation, b.operation)
end


TermInterface.istree(n::ENodeTerm) = true
TermInterface.exprhead(n::ENodeTerm) = n.exprhead
TermInterface.operation(n::ENodeTerm) = n.operation 
TermInterface.arguments(n::ENodeTerm) = n.args 
TermInterface.arity(n::ENodeTerm) = length(n.args)

# This optimization comes from SymbolicUtils
# The hash of an enode is cached to avoid recomputing it.
# Shaves off a lot of time in accessing dictionaries with ENodes as keys.
function Base.hash(t::ENodeTerm{T}, salt::UInt) where {T}
    !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
    h = t.hash[]
    !iszero(h) && return h
    h′ = hash(t.args,  hash(t.exprhead, hash(t.operation, hash(T, salt))))
    t.hash[] = h′
    return h′
end


function toexpr(n::ENodeTerm)
    eh = exprhead(n)
    if isnothing(eh)
        return operation(n) # n is a constant enode
    end
    similarterm(Expr, operation(n), map(i -> Symbol(i, "ₑ"), arguments(n)); exprhead=exprhead(n))
end


# ==================================================
# ENode Literal
# ==================================================

mutable struct ENodeLiteral{T} <: AbstractENode{T}
    value::T
    hash::Ref{UInt}
end

TermInterface.istree(n::ENodeLiteral) = false
TermInterface.exprhead(n::ENodeLiteral) = nothing
TermInterface.operation(n::ENodeLiteral) = n.value 
TermInterface.arity(n::ENodeLiteral) = 0

ENodeLiteral(a::T) where{T} = ENodeLiteral{T}(a, Ref{UInt}(0))

Base.:(==)(a::ENodeLiteral, b::ENodeLiteral) = isequal(a.value, b.value) 


function Base.hash(t::ENodeLiteral{T}, salt::UInt) where {T}
    !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
    h = t.hash[]
    !iszero(h) && return h
    h′ = hash(t.value, hash(T, salt))
    t.hash[] = h′
    return h′
end


termtype(x::AbstractENode{T}) where T = T

toexpr(n::ENodeLiteral) = operation(n)

function Base.show(io::IO, x::ENodeTerm{T}) where {T}
    print(io, "ENode{$T}(", toexpr(x), ")")
end

Base.show(io::IO, x::ENodeLiteral) = print(io, toexpr(x))
