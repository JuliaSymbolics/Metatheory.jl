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
const HashCons = Dict{Any,Int64}
const ParentMem = Dict{Int64,Vector{Parent}}
const AnalysisData = Dict{Int64,Any}
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
    # parents::ParentMem
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


"""
Inserts an e-node in an [`EGraph`](@ref)
"""
function add!(G::EGraph, n)::EClass
    if n isa EClass
        return EClass(find(G, n))
    end

    @debug("adding ", n)
    canonicalize!(G.U, n)
    if haskey(G.H, n)
        return find(G, G.H[n]) |> EClass
    end
    @debug(n, " not found in H")

    id = push!(G.U) # create new singleton eclass

    for child_eclass ∈ getfunargs(n)
        addparent!(G.M[child_eclass.id], (n, id))
    end

    G.H[n] = id

    classdata = EClassData(id, [n], [])
    G.M[id] = classdata

    # cache the eclass for the symbol for faster matching
    sym = getfunsym(n)
    if !haskey(G.symcache, sym)
        G.symcache[sym] = []
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
function addexpr!(G::EGraph, e)::EClass
    e = cleanast(e)
    df_walk((x -> add!(G, x)), e; skip_call = true)
end

function clean_enode!(g::EGraph, t, to::Int64)
    delete!(g.H, t)
    canonicalize!(g.U, t)
    g.H[t] = to
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
    id_u = union!(G.U, id_a, id_b)

    @debug "merging" id_a id_b

    from, to = if (id_u == id_a)
        id_b, id_a
    elseif (id_u == id_b)
        id_a, id_b
    else
        error("egraph invariant maintenance error")
    end

    push!(G.dirty, id_u)

    G.M[from].nodes = map(G.M[from].nodes) do x
        clean_enode!(G, x, to)
    end
    G.M[to].nodes = map(G.M[to].nodes) do x
        clean_enode!(G, x, to)
    end
    G.M[to] = union!(G.M[to], G.M[from])
    delete!(G.M, from)

    # canonicalize the root if needed
    if from == G.root
        G.root = to
    end

    for analysis ∈ G.analyses
        if haskey(analysis, from) && haskey(analysis, to)
            analysis[to] = join(analysis, analysis[from], analysis[to])
            delete!(analysis, from)
        end
    end

    return id_u
end

"""
Returns the canonical e-class id for a given e-class.
"""
find(G::EGraph, a::Int64)::Int64 = find_root!(G.U, a)
find(G::EGraph, a::EClass)::Int64 = find_root!(G.U, a.id)

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
        foreach(todo) do x
            repair!(egraph, x)
        end
    end

    for (sym, ids) ∈ egraph.symcache
        egraph.symcache[sym] = unique(ids .|> x -> find(egraph, x))
    end

    if egraph.root != 0
        egraph.root = find(egraph, egraph.root)
    end
end

function repair!(G::EGraph, id::Int64)
    id = find(G, id)
    ecdata = G.M[id]
    @debug "repairing " id

    for (p_enode, p_eclass) ∈ ecdata.parents
        #old_id = G.H[p_enode]
        #delete!(G.M, old_id)
        delete!(G.H, p_enode)
        @debug "deleted from H " p_enode
        n = canonicalize(G.U, p_enode)
        n_id = find(G, p_eclass)
        G.H[n] = n_id
    end

    new_parents = OrderedDict{Any,Int64}()

    for (p_enode, p_eclass) ∈ ecdata.parents
        canonicalize!(G.U, p_enode)
        # deduplicate parents
        if haskey(new_parents, p_enode)
            @debug "merging classes" p_eclass (new_parents[p_enode])
            merge!(G, p_eclass, new_parents[p_enode])
        end
        new_parents[p_enode] = find(G, p_eclass)
    end
    ecdata.parents = collect(new_parents) .|> Tuple
    @debug "updated parents " id G.parents[id]


    # Analysis invariant maintenance
    for an ∈ G.analyses
        haskey(an, id) && modify!(an, id)
        # modify!(an, id)
        id = find(G, id)
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
end


"""
Recursive function that traverses an [`EGraph`](@ref) and
returns a vector of all reachable e-classes from a given e-class id.
"""
function reachable(g::EGraph, id::Int64; hist=Int64[])
    id = find(g, id)
    hist = hist ∪ [id]
    for n ∈ g.M[id]
        if n isa Expr
            for child_eclass ∈ getfunargs(n)
                c_id = child_eclass.id
                if c_id ∉ hist
                    hist = hist ∪ reachable(g, c_id; hist=hist)
                end
            end
        end
    end

    return hist
end
