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
    println("canonicalized ", n, " to ", ne)
    return ne
end

function canonicalize!(U::IntDisjointSets, n::Expr)
    @assert isenode(n)
    start = isexpr(n, :call) ? 2 : 1
    n.args[start:end] = [EClass(find_root!(U, x.id)) for x ∈ n.args[start:end]]
    println("canonicalized ", n)
    return n
end


# literals are already canonical
canonicalize(U::IntDisjointSets, n) = n
canonicalize!(U::IntDisjointSets, n) = n

struct EGraph
    U::IntDisjointSets       # equality relation over e-class ids
    M::Dict{Int64, Vector{Any}}  # id => sets of e-nodes
    H::Dict{Any, Int64}         # hashcons
    parents::Dict{Int64, Vector{Tuple{Any, Int64}}}  # parent enodes and eclasses
    dirty::Vector{Int64}         # worklist for ammortized upwards merging
    root::Int64
end

EGraph() = EGraph(IntDisjointSets(0), Dict{Int64, Vector{Expr}}(),
    Dict{Expr, Int64}(),
    Dict{Int64, Vector{Int64}}(), Vector{Int64}(), 0)

function addparent!(G::EGraph, a::Int64, parent::Tuple{Any,Int64})
    @assert isenode(parent[1])
    if !haskey(G.parents, a); G.parents[a] = [parent]
    else union!(G.parents[a], [parent]) end
end


function add!(G::EGraph, n)
    println("adding ", n)
    canonicalize!(G.U, n)
    if haskey(G.H, n); return find(G, G.H[n]) |> EClass end   # TODO change with memoization?

    println(n, " not found in H")
    id = push!(G.U)
    if (n isa Expr)
        start = isexpr(n, :call) ? 2 : 1
        display(n.args)
        n.args[start:end] .|> x -> addparent!(G, x.id, (n,id))
    end
    G.H[n] = id
    G.M[id] = [n]
    return EClass(id)
end

function mergeparents!(G::EGraph, a::Int64, b::Int64)
    if !haskey(G.parents, a); G.parents[a] = [] end
    if !haskey(G.parents, b); G.parents[b] = [] end
    G.parents[a] = G.parents[b] = G.parents[a] ∪ G.parents[b]
end

function Base.merge!(G::EGraph, a::Int64, b::Int64)
    fa = find(G,a)
    if fa == find(G,b) return fa end
    root = union!(G.U, a, b)
    G.M[a] = G.M[b] = G.M[a] ∪ G.M[b]
    mergeparents!(G, a, b)
    push!(G.dirty, root)
    return root
end

find(G::EGraph, a::Int64) = find_root!(G.U, a)

addexpr!(G::EGraph, e) = df_walk((x->add!(G,x)), e; skip_call=true)

function EGraph(e)
    G = EGraph()
    rootclass = addexpr!(G, e)
    EGraph(G.U, G.M, G.H, G.parents, G.dirty, rootclass.id)
end


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
        delete!(e.H, p_enode)
        println("deleted ", p_enode, " from H")
        display(e.H)
        n = canonicalize(e.U, p_enode)
        @show e.H[n] = find(e, p_eclass)
    end

    new_parents = Dict()

    for (p_enode, p_eclass) ∈ e.parents[id]
        canonicalize!(e.U, p_enode)
        # deduplicate parents
        if haskey(new_parents, p_enode)
            @debug "merging " p_eclass " and " (new_parents[p_enode])
            merge!(e, p_eclass, new_parents[p_enode])
        end
        new_parents[p_enode] = find(e, p_eclass)
    end
    e.parents[id] = [ (n, id) for (n,id) ∈ new_parents ]
    println(`updated parents: $(e.parents[id])`)
end
