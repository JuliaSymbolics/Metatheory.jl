# Functional implementation of https://egraphs-good.github.io/
# https://dl.acm.org/doi/10.1145/3434304

using DataStructures

"""
Abstract type representing an [`EGraph`](@ref) analysis,
attaching values from a join semi-lattice domain to
an EGraph
"""
abstract type AbstractAnalysis end
const ClassMem = Dict{Int64,EClassData}
const HashCons = Dict{ENode,Int64}
const Analyses = Vector{AbstractAnalysis}
const SymbolCache = Dict{Any, Vector{Int64}}



"""
A concrete type representing an [`EGraph`].
See the [egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304)
for implementation details
"""
mutable struct EGraph
    """stores the equality relations over e-class ids"""
    U::IntDisjointSets
    """map from eclass id to eclasses"""
    M::ClassMem             #
    H::HashCons             # hashcons
    """worklist for ammortized upwards merging"""
    dirty::Vector{Int64}
    root::Int64
    """A vector of analyses associated to the EGraph"""
    analyses::Analyses
    """
    a cache mapping function symbols to e-classes that
    contain e-nodes with that function symbol.
    """
    symcache::SymbolCache
end

EGraph() = EGraph(
    IntDisjointSets(0),
    ClassMem(),
    HashCons(),
    # ParentMem(),
    Vector{Int64}(),
    0,
    Analyses(),
    SymbolCache()
)

function EGraph(e)
    G = EGraph()
    rootclass = addexpr!(G, e)
    G.root = rootclass.id
    G
end

function canonicalize(g::EGraph, n::ENode)
    new_args = map(x -> find(g, x), n.args)
    typeof(n)(n.head, new_args, n.metadata)
end


function canonicalize!(g::EGraph, n::ENode)
    for i ∈ 1:ariety(n)
        n.args[i] = find(g, n.args[i])
    end
    return n
    # n.args = map(x -> find(g, x), n.args)
end


"""
Returns the canonical e-class id for a given e-class.
"""
find(G::EGraph, a::Int64)::Int64 = find_root!(G.U, a)
find(G::EGraph, a::EClass)::Int64 = find_root!(G.U, a.id)


### Definition 2.3: canonicalization
# iscanonical(U::IntDisjointSets, n::Expr) = n == canonicalize(U, n)
iscanonical(g::EGraph, n::ENode) = n == canonicalize(g, n)
iscanonical(g::EGraph, e::EClass) = find(g, e.id) == e.id


"""
Inserts an e-node in an [`EGraph`](@ref)
"""
function add!(G::EGraph, n::ENode)::EClass
    @debug("adding ", n)

    n = canonicalize!(G, n)
    if haskey(G.H, n)
        return find(G, G.H[n]) |> EClass
    end
    @debug(n, " not found in H")

    id = push!(G.U) # create new singleton eclass

    for c_id ∈ n.args
        addparent!(G.M[c_id], n, id)
    end

    G.H[n] = id

    classdata = EClassData(id, OrderedSet([n]), OrderedDict{ENode, Int64}())
    G.M[id] = classdata

    # cache the eclass for the symbol for faster matching
    sym = n.head
    if !haskey(G.symcache, sym)
        G.symcache[sym] = Int64[]
    end
    push!(G.symcache[sym], id)

    # make analyses for new enode
    for analysis ∈ G.analyses
        if !islazy(analysis)
            analysis[id] = make(analysis, n)
            modify!(analysis, id)
        end
    end

    return EClass(id)
end

"""
Recursively traverse an [`Expr`](@ref) and insert terms into an
[`EGraph`](@ref). If `e` is not an [`Expr`](@ref), then directly
insert the literal into the [`EGraph`](@ref).
"""
function addexpr_rec!(G::EGraph, e)::EClass
    # e = preprocess(e)
    # println("========== $e ===========")
    if e isa EClass
        return e
    end

    if istree(e)
        args = getargs(e)
        n = length(args)
        class_ids = Vector{Int64}(undef, n)
        for i ∈ 1:n
            # println("child $child")
            @inbounds child = args[i]
            c_eclass = addexpr!(G, child)
            @inbounds class_ids[i] = c_eclass.id
        end
        node = ENode(e, class_ids)
        return add!(G, node)
    end

    return add!(G, ENode(e))
end

addexpr!(g::EGraph, e) = addexpr_rec!(g, preprocess(e))

function clean_enode!(g::EGraph, t::ENode, to::Int64)
    nt = canonicalize!(g, t)
    if nt != t
        delete!(g.H, t)
    end
    g.H[nt] = to
    return t
end

"""
Given an [`EGraph`](@ref) and two e-class ids, set
the two e-classes as equal.
"""
function Base.merge!(G::EGraph, a::Int64, b::Int64)::Int64
    id_a = find(G, a)
    id_b = find(G, b)
    id_a == id_b && return id_a
    to = union!(G.U, id_a, id_b)

    @debug "merging" id_a id_b

    from = (to == id_a) ? id_b : id_a

    push!(G.dirty, to)

    G.M[to] = union!(G.M[to], G.M[from])
    # G.M[from] = G.M[to]
    delete!(G.M, from)

    for analysis ∈ G.analyses
        if haskey(analysis, from) && haskey(analysis, to)
            analysis[to] = join(analysis, analysis[from], analysis[to])
            delete!(analysis, from)
        end
    end

    return to
end


"""
This function restores invariants and executes
upwards merging in an [`EGraph`](@ref). See
the [egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304)
for more details.
"""
function rebuild!(egraph::EGraph)
    while !isempty(egraph.dirty)
        todo = unique([find(egraph, id) for id ∈ egraph.dirty])
        empty!(egraph.dirty)
        for x ∈ todo
            repair!(egraph, x)
        end
    end

    for (sym, ids) ∈ egraph.symcache
        egraph.symcache[sym] = unique(ids .|> x -> find(egraph, x))
    end

    if egraph.root != 0
        egraph.root = find(egraph, egraph.root)
    end

    # for i ∈ 1:length(egraph.U)
    #     find_root!(egraph.U, i)
    # end
    # INVARIANTS ASSERTIONS
    # for (id, c) ∈  egraph.M
    # #     ecdata.nodes = map(n -> canonicalize(egraph.U, n), ecdata.nodes)
    #     for an ∈ egraph.analyses
    #         if haskey(an, id)
    #             @assert an[id] == mapreduce(x -> make(an, x), (x, y) -> join(an, x, y), c.nodes)
    #         end
    #     end
    #
    #     for n ∈ c
    #         # println(n)
    #         # println("canon = ", canonicalize(egraph, n))
    #         @assert egraph.H[canonicalize(egraph, n)] == find(egraph, id)
    #     end
    # end
end

function repair!(G::EGraph, id::Int64)
    id = find(G, id)
    ecdata = G.M[id]
    @debug "repairing " id

    for (p_enode, p_eclass) ∈ ecdata.parents
        clean_enode!(G, p_enode, find(G, p_eclass))
    end

    new_parents = OrderedDict{ENode,Int64}()

    for (p_enode, p_eclass) ∈ ecdata.parents
        p_enode = canonicalize!(G, p_enode)
        # deduplicate parents
        if haskey(new_parents, p_enode)
            @debug "merging classes" p_eclass (new_parents[p_enode])
            merge!(G, p_eclass, new_parents[p_enode])
        end
        new_parents[p_enode] = find(G, p_eclass)
    end
    ecdata.parents = new_parents
    @debug "updated parents " id G.parents[id]

    # ecdata.nodes = map(n -> canonicalize(G.U, n), ecdata.nodes)

    # Analysis invariant maintenance
    for an ∈ G.analyses
        haskey(an, id) && modify!(an, id)
        # modify!(an, id)
        # id = find(G, id)
        for (p_enode, p_eclass) ∈ ecdata.parents
            # p_eclass = find(G, p_eclass)
            if !islazy(an) && !haskey(an, p_eclass)
                an[p_eclass] = make(an, p_enode)
            end
            if haskey(an, p_eclass)
                new_data = join(an, an[p_eclass], make(an, p_enode))
                if new_data != an[p_eclass]
                    an[p_eclass] = new_data
                    push!(G.dirty, p_eclass)
                end
            end
        end
    end

    # ecdata.nodes = map(n -> canonicalize(G.U, n), ecdata.nodes)

end


"""
Recursive function that traverses an [`EGraph`](@ref) and
returns a vector of all reachable e-classes from a given e-class id.
"""
function reachable(g::EGraph, id::Int64)
    id = find(g, id)
    hist = Int64[id]
    todo = Int64[id]
    while !isempty(todo)
        curr = find(g, pop!(todo))
        for n ∈ g.M[curr]
            nn = canonicalize(g, n)
            # println("node in reachability is ", n)
            for c_id ∈ nn.args
                if c_id ∉ hist
                    push!(hist, c_id)
                    push!(todo, c_id)
                end
            end
        end
    end

    return hist
end
