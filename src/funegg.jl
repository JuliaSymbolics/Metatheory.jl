include("util.jl")

# Functional implementation of https://egraphs-good.github.io/
# https://dl.acm.org/doi/10.1145/3434304

using DataStructures
using AbstractTrees
using Test

## Implement AbstractTrees to pretty print the AST tree in CLI

children(e::Expr) = e.args
AbstractTrees.printnode(io::IO, node::Expr) = show(io, node.head) #show(IOContext(io, :compact => true), node)


## Utility methods


struct EClass
    id::UInt
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

@test isenode(2) == true
@test isenode( :(2 + 3)  ) == false
@test isenode( EClass(2) ) == false
@test isenode( Expr(:call, :foo, EClass(2)) ) == true
@test isenode( Expr(:call, :foo, 3, EClass(2)) ) == false

function pushnew!(U::DisjointSets, x)
    x ∈ U ? nothing : push!(U, x)
end

## Step 2: from an annotated AST, build (U,M,H) (can be merged with step one)


### Definition 2.3: canonicalization
iscanonical(U::DisjointSets{UInt}, n::Expr) = n == canonicalize(U, n)
iscanonical(U::DisjointSets{UInt}, e::EClass) = find_root!(U, e.id) == e.id

# canonicalize an e-term n
# throws a KeyError from find_root! if any of the child classes
# was not found as the representative element in a set in U
function canonicalize(U::DisjointSets{UInt}, n::Expr)
    @assert isenode(n)
    start = isexpr(n, :call) ? 2 : 1
    ne = copy(n)
    ne.args[start:end] = [EClass(find_root!(U, x.id)) for x ∈ ne.args[start:end]]
    println("canonicalized ", n, " to ", ne)
    return ne
end

function canonicalize!(U::DisjointSets{UInt}, n::Expr)
    @assert isenode(n)
    start = isexpr(n, :call) ? 2 : 1
    n.args[start:end] = [EClass(find_root!(U, x.id)) for x ∈ n.args[start:end]]
    println("canonicalized ", n)
    return n
end


# literals are already canonical
canonicalize(U::DisjointSets{UInt}, n) = n
canonicalize!(U::DisjointSets{UInt}, n) = n

struct EGraph
    U::DisjointSets{UInt}       # equality relation over e-class ids
    M::Dict{UInt, Vector{Any}}  # id => sets of e-nodes
    H::Dict{Any, UInt}         # hashcons
    parents::Dict{UInt, Vector{Tuple{Any, UInt}}}  # parent enodes and eclasses
    dirty::Vector{UInt}         # worklist for ammortized upwards merging
    root::UInt
end

EGraph() = EGraph(DisjointSets{UInt}(), Dict{UInt, Vector{Expr}}(),
    Dict{Expr, UInt}(),
    Dict{UInt, Vector{UInt}}(), Vector{UInt}(), 0)

function addparent!(G::EGraph, a::UInt, parent::Tuple{Any,UInt})
    @assert isenode(parent[1])
    if !haskey(G.parents, a); G.parents[a] = [parent]
    else union!(G.parents[a], [parent]) end
end


function add!(G::EGraph, n)
    println("adding ", n)
    canonicalize!(G.U, n)
    if haskey(G.H, n); return find(G, G.H[n]) |> EClass end   # TODO change with memoization?

    println(n, " not found in H")
    id = hash(n)
    pushnew!(G.U, id)
    if (n isa Expr)
        start = isexpr(n, :call) ? 2 : 1
        display(n.args)
        n.args[start:end] .|> x -> addparent!(G, x.id, (n,id))
    end
    G.H[n] = id
    G.M[id] = [n]
    return EClass(id)
end


function Base.merge!(G::EGraph, a::UInt, b::UInt)
    fa = find(G,a)
    if fa == find(G,b) return fa end
    root = union!(G.U, a, b)
    G.M[a] = G.M[b] = G.M[a] ∪ G.M[b]
    G.parents[a] = G.parents[b] = G.parents[a] ∪ G.parents[b]
    push!(G.dirty, root)
    return root
end

find(G::EGraph, a::UInt) = find_root!(G.U, a)

# recursively hash and add a term to the egraph

recadd!(G::EGraph, e) = df_walk((x->add!(G,x)), e; skip_call=true)

function EGraph(e)
    G = EGraph()
    rootclass = recadd!(G, e)
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

using Printf

function repair!(e::EGraph, id::UInt)
    @printf "repairing %x \n" id
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
            println(`merging $p_eclass and $(new_parents[p_enode])`)
            merge!(e, p_eclass, new_parents[p_enode])
        end
        new_parents[p_enode] = find(e, p_eclass)
    end
    e.parents[id] = [ (n, id) for (n,id) ∈ new_parents ]
    println(`updated parents: $(e.parents[id])`)
end


## SPAZZATURA

#testexpr = :(42a + b * (foo($(Dict(:x => 2)), 42)))
testexpr = :((a * 2)/2)

#t1 = recadd(G, testexpr)
G = EGraph(testexpr)
display(G.U)
display(G.M)
display(G.H)
display(G.parents)
display(G.dirty)

testmatch = :(a << 1)
t2 = recadd!(G, testmatch)
display(G.U)
display(G.M)


# manual merge test
merge!(G, t2.id, 0xd269aee6c8a22b36)

in_same_set(G.U, t2.id, 0xd269aee6c8a22b36)

display(G.U)
display(G.M)
display(G.dirty)
display(G.parents)

# DOES NOT UPWARD MERGE

## TODO Test UPWARD merging

testexpr = :(f(a,b) + f(a,c))
G = EGraph(testexpr)
display(G.M)
display(G.H)

t2 = recadd!(G, :c)
display(G.M)
display(G.H)

# merge b and c
c_id = merge!(G, t2.id, 0x8e5e38f3ddbfbcc1)

in_same_set(G.U, c_id, 0x8e5e38f3ddbfbcc1)
in_same_set(G.U, t2.id, 0x8e5e38f3ddbfbcc1)

find_root!(G.U, t2.id)


display(G.M)
display(G.H)
display(G.dirty)
display(G.parents)

# DOES NOT UPWARD MERGE


rebuild!(G)

# f(a,b) = f(a,c)
in_same_set(G.U, 0xadfb9a19461fbd80, 0xe4646feaf0d276f4)

# IT WORKS

display(G.M)
display(G.H)
display(G.dirty)
display(G.parents)
