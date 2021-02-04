# Functional implementation of https://egraphs-good.github.io/
# https://dl.acm.org/doi/10.1145/3434304

using DataStructures

abstract type AbstractAnalysis end


mutable struct EGraph
    U::IntDisjointSets       # equality relation over e-class ids
    M::Dict{Int64, Vector{Any}}  # id => sets of e-nodes
    H::Dict{Any, Int64}         # hashcons
    parents::Dict{Int64, Vector{Tuple{Any, Int64}}}  # parent enodes and eclasses
    dirty::Vector{Int64}         # worklist for ammortized upwards merging
    root::Int64
    analyses::Dict{AbstractAnalysis, Dict{Int64, Any}}
end

EGraph() = EGraph(IntDisjointSets(0), Dict{Int64, Vector{Expr}}(),
    Dict{Expr, Int64}(),
    Dict{Int64, Vector{Int64}}(), Vector{Int64}(), 0,
    Dict{AbstractAnalysis, Dict{Int64, Any}}())

function EGraph(e)
    G = EGraph()
    rootclass = addexpr!(G, e)
    G.root = rootclass.id
    G
end


function EGraph(e, analyses::Vector{<:AbstractAnalysis})
    G = EGraph()
    for i ∈ analyses
        G.analyses[i] = Dict{Int64, Any}()
    end

    rootclass = addexpr!(G, e)
    G.root = rootclass.id

    G
end

modify!(analysis::AbstractAnalysis, G::EGraph, id::Int64) = error("Analysis does not implement modify!")
join(analysis::AbstractAnalysis, G::EGraph, a, b) = error("Analysis does not implement join")
make(analysis::AbstractAnalysis, G::EGraph, a) = error("Analysis does not implement make")


function addanalysis!(G::EGraph, analysis::AbstractAnalysis)
    if haskey(G.analyses, analysis); return end
    G.analyses[analysis] = Dict{Int64, Any}()
    for (id, class) ∈ G.M
        for n ∈ class

        end
        push!(G.dirty, id)
    end
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
    id = push!(G.U) # create new singleton eclass
    !haskey(G.parents, id) && (G.parents[id] = [])
    if (n isa Expr)
        start = isexpr(n, :call) ? 2 : 1
        n.args[start:end] .|> x -> addparent!(G, x.id, (n,id))
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

addexpr!(G::EGraph, e) = df_walk((x->add!(G,x)), e; skip_call=true)

function mergeparents!(G::EGraph, from::Int64, to::Int64)
    !haskey(G.parents, from) && (G.parents[from] = []; return)
    !haskey(G.parents, to) && (G.parents[to] = [])

    # TODO optimize

    union!(G.parents[to], G.parents[from])
    # G.parents[to] = map(G.parents[to]) do (p_enode, p_eclass)
    #     (canonicalize!(G.U, p_enode), find(G, p_eclass))
    # end
    #G.parents[from] = G.parents[to]
    #G.parents[from] = []
end

# Does a from-to space optimization by deleting stale terms
# from G.M, taken from phil zucker's implementation.
# TODO may this optimization be slowing down things??
function Base.merge!(G::EGraph, a::Int64, b::Int64)
    id_a = find(G,a)
    id_b = find(G,b)
    id_a == id_b && return id_a
    id_u = union!(G.U, id_a, id_b)

    @debug "merging" id_a id_b


    from, to = if (id_u == id_a) id_b, id_a
        elseif (id_u == id_b) id_a, id_b
        else error("egraph invariant maintenance error") end

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
    for (analysis, data) ∈ G.analyses
        data[to] = join(analysis, G, data[from], data[to])
    end
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

function repair!(G::EGraph, id::Int64)
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

    new_parents = Dict()

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
        modify!(analysis, G, id)
        for (p_enode, p_eclass) ∈ G.parents[id]
            new_data = join(analysis, G, data[p_eclass], make(analysis, G, p_enode))
            if new_data != data[p_eclass]
                data[p_eclass] = new_data
                push!(G.dirty, p_eclass)
            end
        end
    end
end
