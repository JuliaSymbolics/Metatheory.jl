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

# NOTE: iseclass and isenode are mutually recursive

# # check if an expr is an eclass id annotation
# iseclass(e::Expr) =
#     isexpr(e, :eclass) &&
#     e.args[1] isa UInt #&&
#     #length(e.args) > 1 && all(isenode, e.args[2:end])
#
# # literals are not e-classes
# iseclass(x) = false
#
# @test iseclass(2) == false
# @test iseclass(Dict(:x => 3 )) == false
# @test iseclass(Expr(:eclass, "hi")) == false
# @test iseclass(Expr(:eclass, 0)) == false
# @test iseclass(Expr(:eclass, UInt(3), 1)) == true
# @test iseclass(Expr(:eclass, UInt(3), Expr(:(=), hashnode(2), hashnode(3)))) == true
# @test iseclass(Expr(:eclass, UInt(3), Expr(:(=), 3, 2))) == true

struct EClass
    id::UInt
end

# check if an expr is an enode ⟺
# all args are e-classes
function isenode(e::Expr)
    if isexpr(e, :eclass) return false end
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


#getid(e::Expr) = iseclass(e) ? e.args[1] : error(`$e not a valid eclass`)


# annotate an expression tree with :eclass nodes, containing the e-class id (expr hash)
#hashnode(x) = Expr(:eclass, hash(x), x)


## Step 1:

# annotate all (excluding function names in :call exprs.) nodes of the AST
# with an e-class metadata node, starting from the leaves of AST and going upwards.
# TODO verify this property
# produces a valid hierarchy, forall e-class node x, containing
# class id in x.args[1] and valid e-nodes in args[2:end]
#annot_eclass(e::Expr) = df_walk(hashnode, e; skip_call=true)

#testexpr = :(42a + b * (foo($(Dict(:x => 2)), 42)))
#testexpr = :((a * 2)/a)

#test_annot_hash = annot_eclass(testexpr)
#print_tree(test_annot_hash, Inf)

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
    ne.args[start, end] = [EClass(find_root!(U, x.id)) for x ∈ ne.args[start:end]]
    return ne
end

# literals are already canonical
canonicalize(U::DisjointSets{UInt}, n) = n

function lookup(U::DisjointSets{UInt}, n)
    @assert isenode(n)
    a = UInt(0)
    try a = hash(canonicalize(U, n))
    catch e; (e isa KeyError) ? nothing : throw(e) end
    a ∈ U ? a : nothing
end


struct EGraph
    U::DisjointSets{UInt}       # equality relation over e-class ids
    M::Dict{UInt, Vector{Any}}  # id => sets of e-nodes
    #H::????? hashcons?
    dirty::Vector{UInt}         # worklist for ammortized upwards merging
    root::UInt
end

EGraph() = EGraph(DisjointSets{UInt}(), Dict{UInt, Vector{Expr}}(), Vector{UInt}(), 0)

function add!(G::EGraph, n)
    println("adding ", n)
    @assert isenode(n)
    a = lookup(G.U,n)
    println(n, " |> lookup  ==== ",a)
    if a == nothing
        println(n, " not found in U")
        a = hash(n)
        pushnew!(G.U, a)
        if (n isa Expr)
            start = isexpr(n, :call) ? 2 : 1
            n.args[start:end] .|> x -> pushnew!(G.U, x.id)
        end
        G.M[a] = [n]
    end
    return EClass(a)
end

function Base.merge!(G::EGraph, a::UInt, b::UInt)
    fa = find(G,a)
    if fa == find(G,b) return fa end
    root = union!(G.U, a, b)
    G.M[a] = G.M[b] = G.M[a] ∪ G.M[b]
    push!(G.dirty, root)
    return root
end

find(G::EGraph, a::UInt) = find_root!(G.U, a)

# recursively hash and add a term to the egraph

recadd!(G::EGraph, e) = df_walk((x->add!(G,x)), e; skip_call=true)

function EGraph(e::Expr)
    G = EGraph()
    rootclass = recadd!(G, e)
    EGraph(G.U, G.M, G.dirty, rootclass.id)
end

## SPAZZATURA

#G = EGraph()

#println(G)

#testexpr = :(42a + b * (foo($(Dict(:x => 2)), 42)))
testexpr = :((a * 2)/a)

#t1 = recadd(G, testexpr)
G = EGraph(testexpr)
display(G.U)
display(G.M)

testmatch = :(a << 1)
t2 = recadd!(G, testmatch)
display(G.U)
display(G.M)


# manual merge test
merge!(G, t2.id, 0xd269aee6c8a22b36)

in_same_set(G.U, t2.id, 0xd269aee6c8a22b36)

display(G.U)
display(G.M)

## TODO Test UPWARD merging

testexpr = :(f(a,b) + f(b,c))
G = EGraph(testexpr)
display(G.U)
display(G.M)

testrewrite = :c
t2 = recadd!(G, testrewrite)
display(G.U)
display(G.M)

# merge b and c
merge!(G, t2.id, 0x8e5e38f3ddbfbcc1)

display(G.U)
display(G.M)

# DOES NOT UPWARD MERGE

## TODO
