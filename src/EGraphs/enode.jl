using DataStructures
using Base.Meta

struct EClass
    id::Int64
end

"""
Check if an expr is an enode ⟺ all args are e-classes
"""
function isenode(e::Expr)
    return all(x -> x isa EClass, getfunargs(e))
end
# literals are enodes
isenode(x::EClass) = false
isenode(x) = true

### Definition 2.3: canonicalization
iscanonical(U::IntDisjointSets, n::Expr) = n == canonicalize(U, n)
iscanonical(U::IntDisjointSets, e::EClass) = find_root!(U, e.id) == e.id

# canonicalize an e-term n
# throws a KeyError from find_root! if any of the child classes
# was not found as the representative element in a set in U
function canonicalize(U::IntDisjointSets, n::Expr)
    @assert isenode(n)
    ne = copy(n)
    setfunargs!(ne, [EClass(find_root!(U, x.id)) for x ∈ getfunargs(ne)])
    @debug("canonicalized ", n, " to ", ne)
    return ne
end

# canonicalize in place
function canonicalize!(U::IntDisjointSets, n::Expr)
    @assert isenode(n)
    setfunargs!(n, [EClass(find_root!(U, x.id)) for x ∈ getfunargs(n)])
    @debug("canonicalized ", n)
    return n
end


# literals are already canonical
canonicalize(U::IntDisjointSets, n) = n
canonicalize!(U::IntDisjointSets, n) = n
