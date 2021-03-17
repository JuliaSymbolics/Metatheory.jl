# Functional implementation of https://egraphs-good.github.io/
# https://dl.acm.org/doi/10.1145/3434304

using DataStructures

"""
Abstract type representing an [`EGraph`](@ref) analysis,
attaching values from a join semi-lattice domain to
an EGraph
"""
const ClassMem = Dict{Int64,EClass}
const HashCons = Dict{ENode,Int64}
const Analyses = Set{Type{<:AbstractAnalysis}}
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
    g = EGraph()
    rootclass = addexpr!(g, e)
    g.root = rootclass.id
    g
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
find(g::EGraph, a::Int64)::Int64 = find_root!(g.U, a)
find(g::EGraph, a::EClass)::Int64 = find_root!(g.U, a.id)


geteclass(g::EGraph, a::Int64)::EClass = g.M[find(g, a)]
geteclass(g::EGraph, a::EClass)::Int64 = a


### Definition 2.3: canonicalization
# iscanonical(U::IntDisjointSets, n::Expr) = n == canonicalize(U, n)
iscanonical(g::EGraph, n::ENode) = n == canonicalize(g, n)
iscanonical(g::EGraph, e::EClass) = find(g, e.id) == e.id

function canonicalize!(g::EGraph, e::EClass)
    e.id = find(g, e.id)
end

"""
Inserts an e-node in an [`EGraph`](@ref)
"""
function add!(g::EGraph, n::ENode)::EClass
    @debug("adding ", n)

    n = canonicalize!(g, n)
    if haskey(g.H, n)
        return geteclass(g, find(g, g.H[n]))
    end
    @debug(n, " not found in H")

    id = push!(g.U) # create new singleton eclass

    for c_id ∈ n.args
        addparent!(g.M[c_id], n, id)
    end

    g.H[n] = id

    classdata = EClass(id, OrderedSet([n]), OrderedDict{ENode, Int64}())
    g.M[id] = classdata

    # cache the eclass for the symbol for faster matching
    sym = n.head
    if !haskey(g.symcache, sym)
        g.symcache[sym] = Int64[]
    end
    push!(g.symcache[sym], id)

    # make analyses for new enode
    for an ∈ g.analyses
        if !islazy(an)
            setdata!(classdata, an, make(an, g, n))
            modify!(an, g, id)
        end
    end

    return classdata
end

"""
Recursively traverse an [`Expr`](@ref) and insert terms into an
[`EGraph`](@ref). If `e` is not an [`Expr`](@ref), then directly
insert the literal into the [`EGraph`](@ref).
"""
function addexpr_rec!(g::EGraph, e)::EClass
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
            c_eclass = addexpr!(g, child)
            @inbounds class_ids[i] = c_eclass.id
        end
        node = ENode(e, class_ids)
        return add!(g, node)
    end

    return add!(g, ENode(e))
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
function Base.merge!(g::EGraph, a::Int64, b::Int64)::Int64
    id_a = find(g, a)
    id_b = find(g, b)
    id_a == id_b && return id_a
    to = union!(g.U, id_a, id_b)

    @debug "merging" id_a id_b

    from = (to == id_a) ? id_b : id_a

    push!(g.dirty, to)

    from_class = g.M[from]
    to_class = g.M[to]

    g.M[to] = union!(from_class, to_class)
    # g.M[from] = g.M[to]
    delete!(g.M, from)

    # mutable version
    # for an ∈ g.analyses
    #     if hasdata(from_class, an) && hasdata(to_class, an)
    #         from_data = getdata(from_class, an)
    #         to_data = getdata(to_class, an)
    #         setdata!(to_class, an, join(an, from_data, to_data))
    #     end
    # end

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

function repair!(g::EGraph, id::Int64)
    id = find(g, id)
    ecdata = g.M[id]
    @debug "repairing " id

    for (p_enode, p_eclass) ∈ ecdata.parents
        clean_enode!(g, p_enode, find(g, p_eclass))
    end

    new_parents = OrderedDict{ENode,Int64}()

    for (p_enode, p_eclass) ∈ ecdata.parents
        p_enode = canonicalize!(g, p_enode)
        # deduplicate parents
        if haskey(new_parents, p_enode)
            @debug "merging classes" p_eclass (new_parents[p_enode])
            merge!(g, p_eclass, new_parents[p_enode])
        end
        new_parents[p_enode] = find(g, p_eclass)
    end
    ecdata.parents = new_parents
    @debug "updated parents " id g.parents[id]

    # ecdata.nodes = map(n -> canonicalize(g.U, n), ecdata.nodes)

    # Analysis invariant maintenance
    for an ∈ g.analyses
        hasdata(ecdata, an) && modify!(an, g, id)
        # modify!(an, id)
        # id = find(g, id)
        for (p_enode, p_id) ∈ ecdata.parents
            # p_eclass = find(g, p_eclass)
            p_eclass = g.M[p_id]
            if !islazy(an) && !hasdata(p_eclass, an)
                setdata!(p_eclass, an, make(an, g, p_enode))
            end
            if hasdata(p_eclass, an)
                p_data = getdata(p_eclass, an)

                new_data = join(an, p_data, make(an, g, p_enode))
                if new_data != p_data
                    setdata!(p_eclass, an, new_data)
                    push!(g.dirty, p_id)
                end
            end
        end
    end

    # ecdata.nodes = map(n -> canonicalize(g.U, n), ecdata.nodes)

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
