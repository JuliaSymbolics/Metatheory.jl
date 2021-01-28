# Functional implementation of https://egraphs-good.github.io/
# https://dl.acm.org/doi/10.1145/3434304

using DataStructures

struct EClass
    id::Int64
    # parents::Vector{EClass}
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


## Step 2: from an annotated AST, build (U,M,H) (can be merged with step one)


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

mutable struct EGraph
    U::IntDisjointSets       # equality relation over e-class ids
    M::Dict{Int64, Vector{Any}}  # id => sets of e-nodes
    H::Dict{Any, Int64}         # hashcons
    parents::Dict{Int64, Vector{Tuple{Any, Int64}}}  # parent enodes and eclasses
    dirty::Vector{Int64}         # worklist for ammortized upwards merging
    root::Int64
end

const TIMEOUT = 3000


EGraph() = EGraph(IntDisjointSets(0), Dict{Int64, Vector{Expr}}(),
    Dict{Expr, Int64}(),
    Dict{Int64, Vector{Int64}}(), Vector{Int64}(), 0)


function EGraph(e)
    G = EGraph()
    rootclass = addexpr!(G, e)
    G.root = rootclass.id
    G
end



function addparent!(G::EGraph, a::Int64, parent::Tuple{Any,Int64})
    @assert isenode(parent[1])
    if !haskey(G.parents, a); G.parents[a] = [parent]
    else union!(G.parents[a], [parent]) end
end


function add!(G::EGraph, n)
    @debug("adding ", n)
    canonicalize!(G.U, n)
    if haskey(G.H, n); return find(G, G.H[n]) |> EClass end
    @debug(n, " not found in H")
    id = push!(G.U)
    !haskey(G.parents, id) && (G.parents[id] = [])
    if (n isa Expr)
        start = isexpr(n, :call) ? 2 : 1
        n.args[start:end] .|> x -> addparent!(G, x.id, (n,id))
    end
    G.H[n] = id
    G.M[id] = [n]
    return EClass(id)
end

addexpr!(G::EGraph, e) = df_walk((x->add!(G,x)), e; skip_call=true)

function mergeparents!(G::EGraph, from::Int64, to::Int64)
    !haskey(G.parents, from) && (G.parents[from] = []; return)
    !haskey(G.parents, to) && (G.parents[to] = [])

    # TODO optimize

    union!(G.parents[to], G.parents[from])
    G.parents[to] = map(G.parents[to]) do (p_enode, p_eclass)
        (canonicalize!(G.U, p_enode), find(G, p_eclass))
    end
    #G.parents[from] = G.parents[to]
    #G.parents[from] = []
end

# DONE do the from-to space optimization with deleting stale terms
# from G.M that happens already in phil zucker's implementation.
# TODO may this optimization be slowing down things??
function Base.merge!(G::EGraph, a::Int64, b::Int64)
    id_a = find(G,a)
    id_b = find(G,b)
    id_a == id_b && return id_a
    id_u = union!(G.U, id_a, id_b)

    @debug "merging" id_a id_b

    if (id_u == id_a)
        from, to = id_b, id_a
    elseif (id_u == id_b)
        from, to = id_a, id_b
    else
        error("egraph invariant maintenance error")
    end

    push!(G.dirty, id_u)

    clean(t) = begin
        delete!(G.H, t)
        canonicalize!(G.U, t)
        G.H[t] = to
        t
    end

    G.M[from] = map(clean, G.M[from])
    G.M[to] = map(clean, G.M[to])
    G.M[to] = G.M[from] ∪ G.M[to]

    if from == G.root; G.root = to end

    delete!(G.M, from)
    delete!(G.H, from)
    mergeparents!(G, from, to)
    return id_u
end

find(G::EGraph, a::Int64) = find_root!(G.U, a)
find(G::EGraph, a::EClass) = find_root!(G.U, a.id)


function rebuild!(e::EGraph)
    while !isempty(e.dirty)
        todo = unique([ find(e, id) for id ∈ e.dirty ])
        empty!(e.dirty)
        foreach(todo) do x
            repair!(e, x)
        end
    end
end

function repair!(e::EGraph, id::Int64)
    @debug "repairing " id
    for (p_enode, p_eclass) ∈ e.parents[id]
        #old_id = e.H[p_enode]
        #delete!(e.M, old_id)
        delete!(e.H, p_enode)
        @debug "deleted from H " p_enode
        n = canonicalize(e.U, p_enode)
        n_id = find(e, p_eclass)
        e.H[n] = n_id
    end

    new_parents = Dict()

    for (p_enode, p_eclass) ∈ e.parents[id]
        canonicalize!(e.U, p_enode)
        # deduplicate parents
        if haskey(new_parents, p_enode)
            @debug "merging classes" p_eclass (new_parents[p_enode])
            merge!(e, p_eclass, new_parents[p_enode])
        end
        new_parents[p_enode] = find(e, p_eclass)
    end
    e.parents[id] = collect(new_parents) .|> Tuple
    @debug "updated parents " id e.parents[id]
end
