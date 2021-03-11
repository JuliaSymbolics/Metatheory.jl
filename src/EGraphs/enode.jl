using DataStructures
using Base.Meta
using StaticArrays
using AutoHashEquals

@auto_hash_equals struct EClass
    id::Int64
end


@auto_hash_equals struct ENode
    sym::Any
    iscall::Bool
    args::MVector{T, Int64} where T
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


"""
Check if an expr is an enode ⟺ all args are e-classes
"""
function isenode(e::Expr)
    return all(x -> x isa EClass, getfunargs(e))
end
# literals are enodes
isenode(x::EClass) = false
isenode(x) = true

function ENode(e::Expr)
    args = map(x->x.id, getfunargs(e))
    ENode(getfunsym(e), iscall(e), MVector{length(args), Int64}(args...))
end

function ENode(a)
    ENode(a, false, MVector{0, Int64}())
end

ENode(a::ENode) = error()



# canonicalize an e-term n
# throws a KeyError from find_root! if any of the child classes
# was not found as the representative element in a set in U
# function canonicalize(U::IntDisjointSets, n::Expr)
#     @assert isenode(n)
#     ne = copy(n)
#     setfunargs!(ne, [EClass(find_root!(U, x.id)) for x ∈ getfunargs(ne)])
#     @debug("canonicalized ", n, " to ", ne)
#     return ne
# end


# # canonicalize in place
# function canonicalize!(U::IntDisjointSets, n::Expr)
#     @assert isenode(n)
#     setfunargs!(n, [EClass(find_root!(U, x.id)) for x ∈ getfunargs(n)])
#     @debug("canonicalized ", n)
#     return n
# end


# literals are already canonical
# canonicalize(U::IntDisjointSets, n) = n
# canonicalize!(U::IntDisjointSets, n) = n
