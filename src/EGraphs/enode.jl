using DataStructures

struct EClass
    id::Int64
end

# check if an expr is an enode ⟺
# all args are e-classes
function isenode(e::Expr)
    start = isexpr(e, :call) ? 2 : 1
    return all(x -> x isa EClass, e.args[start:end])
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
    start = isexpr(n, :call) ? 2 : 1
    ne = copy(n)
    ne.args[start:end] = [EClass(find_root!(U, x.id)) for x ∈ ne.args[start:end]]
    @debug("canonicalized ", n, " to ", ne)
    return ne
end

# canonicalize in place
function canonicalize!(U::IntDisjointSets, n::Expr)
    @assert isenode(n)
    start = isexpr(n, :call) ? 2 : 1
    n.args[start:end] = [EClass(find_root!(U, x.id)) for x ∈ n.args[start:end]]
    @debug("canonicalized ", n)
    return n
end


# literals are already canonical
canonicalize(U::IntDisjointSets, n) = n
canonicalize!(U::IntDisjointSets, n) = n
