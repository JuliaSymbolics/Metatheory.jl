# Functional implementation of https://egraphs-good.github.io/
# https://dl.acm.org/doi/10.1145/3434304

using DataStructures

abstract type AbstractAnalysis end

const ClassMem = OrderedDict{Int64,Vector{Any}}
const HashCons = Dict{Any,Int64}
const Parent = Tuple{Any,Int64} # parent enodes and eclasses
const ParentMem = Dict{Int64,Vector{Parent}}
const AnalysisData = Dict{Int64,Any}
const Analyses = Dict{AbstractAnalysis,AnalysisData}

mutable struct EGraph
    U::IntDisjointSets       # equality relation over e-class ids
    M::ClassMem           # id => sets of e-nodes
    H::HashCons         # hashcons
    parents::ParentMem
    dirty::Vector{Int64}         # worklist for ammortized upwards merging
    root::Int64
    analyses::Analyses
end

EGraph() = EGraph(
    IntDisjointSets(0),
    ClassMem(),
    HashCons(),
    ParentMem(),
    Vector{Int64}(),
    0,
    Analyses(),
)

function EGraph(e)
    G = EGraph()
    rootclass = addexpr!(G, e)
    G.root = rootclass.id
    G
end


function EGraph(e, analyses::Vector{<:AbstractAnalysis})
    G = EGraph()
    for i ∈ analyses
        G.analyses[i] = Dict{Int64,Any}()
    end

    rootclass = addexpr!(G, e)
    G.root = rootclass.id

    return G
end

function addparent!(G::EGraph, a::Int64, parent::Parent)
    @assert isenode(parent[1])
    if !haskey(G.parents, a)
        G.parents[a] = [parent]
    else
        union!(G.parents[a], [parent])
    end
end


function add!(G::EGraph, n)::EClass
    @debug("adding ", n)
    canonicalize!(G.U, n)
    if haskey(G.H, n)
        return find(G, G.H[n]) |> EClass
    end
    @debug(n, " not found in H")
    id = push!(G.U) # create new singleton eclass
    !haskey(G.parents, id) && (G.parents[id] = [])
    if (n isa Expr)
        start = isexpr(n, :call) ? 2 : 1
        n.args[start:end] .|> x -> addparent!(G, x.id, (n, id))
    end
    G.H[n] = id
    G.M[id] = [n]

    # make analyses for new enode
    for (analysis, data) ∈ G.analyses
        data[id] = make(analysis, G, n)
        modify!(analysis, G, id)
    end

    return EClass(id)
end

addexpr!(G::EGraph, e)::EClass = df_walk((x -> add!(G, x)), e; skip_call = true)

function mergeparents!(G::EGraph, from::Int64, to::Int64)
    !haskey(G.parents, from) && (G.parents[from] = []; return)
    !haskey(G.parents, to) && (G.parents[to] = [])

    union!(G.parents[to], G.parents[from])
    delete!(G.parents, from)
end

# Does a from-to space optimization by deleting stale terms
# from G.M, taken from phil zucker's implementation.
# TODO may this optimization be slowing down things??
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

    clean(t) = begin
        delete!(G.H, t)
        canonicalize!(G.U, t)
        G.H[t] = to
        t
    end

    G.M[from] = map(clean, G.M[from])
    G.M[to] = map(clean, G.M[to])
    G.M[to] = G.M[from] ∪ G.M[to]

    if from == G.root
        G.root = to
    end

    delete!(G.M, from)
    delete!(G.H, from)
    mergeparents!(G, from, to)
    for (analysis, data) ∈ G.analyses
        if haskey(data, from) && haskey(data, to)
            data[to] = join(analysis, G, data[from], data[to])
            delete!(data, from)
        end
    end

    return id_u
end

find(G::EGraph, a::Int64)::Int64 = find_root!(G.U, a)
find(G::EGraph, a::EClass)::Int64 = find_root!(G.U, a.id)


function rebuild!(G::EGraph)
    while !isempty(G.dirty)
        todo = unique([find(G, id) for id ∈ G.dirty])
        empty!(G.dirty)
        foreach(todo) do x
            repair!(G, x)
        end
    end

    G.root = find(G, G.root)
end

function repair!(G::EGraph, id::Int64)
    id = find(G, id)
    @debug "repairing " id

    for (p_enode, p_eclass) ∈ G.parents[id]
        #old_id = G.H[p_enode]
        #delete!(G.M, old_id)
        delete!(G.H, p_enode)
        @debug "deleted from H " p_enode
        n = canonicalize(G.U, p_enode)
        n_id = find(G, p_eclass)
        G.H[n] = n_id
    end

    new_parents = Dict{Any,Int64}()

    for (p_enode, p_eclass) ∈ G.parents[id]
        canonicalize!(G.U, p_enode)
        # deduplicate parents
        if haskey(new_parents, p_enode)
            @debug "merging classes" p_eclass (new_parents[p_enode])
            merge!(G, p_eclass, new_parents[p_enode])
        end
        new_parents[p_enode] = find(G, p_eclass)
    end
    G.parents[id] = collect(new_parents) .|> Tuple
    @debug "updated parents " id G.parents[id]

    # Analysis invariant maintenance
    for (analysis, data) ∈ G.analyses
        # analysisfix(analysis, G, id)
        haskey(data, id) && modify!(analysis, G, id)
        for (p_enode, p_eclass) ∈ G.parents[id]
            # analysisfix(analysis, G, p_eclass)
            if haskey(data, p_eclass)
                new_data = join(
                    analysis,
                    G,
                    data[p_eclass],
                    make(analysis, G, p_enode),
                )
                if new_data != data[p_eclass]
                    data[p_eclass] = new_data
                    push!(G.dirty, p_eclass)
                end
            end
        end
    end
end

# TODO  is this needed? ask Max Willsey
# function analysisfix(analysis, G, id)
#     data = G.analyses[analysis]
#     if !haskey(data, id)
#         class = G.M[id]
#         sup = make(analysis, G, class[1])
#
#         for i ∈ class[2:end]
#             sup = join(analysis, G, sup, make(analysis, G, i))
#         end
#
#         data[id] = sup
#     end
# end
