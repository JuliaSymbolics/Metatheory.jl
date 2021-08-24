# Functional implementation of https://egraphs-good.github.io/
# https://dl.acm.org/doi/10.1145/3434304

using DataStructures
using TermInterface

"""
Abstract type representing an [`EGraph`](@ref) analysis,
attaching values from a join semi-lattice domain to
an EGraph
"""
const ClassMem = Dict{EClassId,EClass}
const HashCons = Dict{ENode,EClassId}
const Analyses = Set{Type{<:AbstractAnalysis}}
const SymbolCache = Dict{Any, Set{EClassId}}
const TermTypes = Dict{Tuple{Any, EClassId}, Type}


"""
A concrete type representing an [`EGraph`].
See the [egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304)
for implementation details
"""
mutable struct EGraph
    """stores the equality relations over e-class ids"""
    # uf::IntDisjointSets{EClassId}
    uf::IntDisjointSet
    """map from eclass id to eclasses"""
    classes::ClassMem
    memo::HashCons             # memo
    """worklist for ammortized upwards merging"""
    dirty::Vector{EClassId}
    root::EClassId
    """A vector of analyses associated to the EGraph"""
    analyses::Analyses
    # """
    # a cache mapping function symbols to e-classes that
    # contain e-nodes with that function symbol.
    # """
    # symcache::SymbolCache
    default_termtype::Type
    termtypes::TermTypes
    numclasses::Int
    numnodes::Int
    # number of rules that have been applied
    # age::Int
end

function EGraph()
    EGraph(
        IntDisjointSet{EClassId}(),
        # IntDisjointSets{EClassId}(0),
        ClassMem(),
        HashCons(),
        # ParentMem(),
        EClassId[],
        -1,
        Analyses(),
        # SymbolCache(),
        Expr,
        TermTypes(),
        0,
        0,
        # 0
    )
end

function EGraph(e; keepmeta=false)
    g = EGraph()
    if keepmeta
        push!(g.analyses, MetadataAnalysis)
    end
    
    rootclass, rootnode = addexpr!(g, e; keepmeta=keepmeta)
    g.root = rootclass.id
    g
end

function settermtype!(g::EGraph, f, ar, T)
    g.termtypes[(f,ar)] = T
end

function settermtype!(g::EGraph, T)
    g.default_termtype = T
end

function gettermtype(g::EGraph, f, ar)
    if haskey(g.termtypes, (f,ar))
        g.termtypes[(f,ar)]
    else 
        g.default_termtype
    end
end


"""
Returns the canonical e-class id for a given e-class.
"""
# function find(g::EGraph, a::EClassId)::EClassId
#     find_root_if_normal(g.uf, a)
# end
function find(g::EGraph, a::EClassId)::EClassId
    find_root(g.uf, a)
end
find(g::EGraph, a::EClass)::EClassId = find(g, a.id)


function geteclass(g::EGraph, a::EClassId)::EClass
    id = find(g, a)
    ec = g.classes[id]
    # @show ec.id id a
    # @assert ec.id == id
    # ec.id = id
    ec
end
# geteclass(g::EGraph, a::EClass)::EClassId = geteclass()
Base.getindex(g::EGraph, i::EClassId) = geteclass(g, i)

### Definition 2.3: canonicalization
iscanonical(g::EGraph, n::ENode) = n == canonicalize(g, n)
iscanonical(g::EGraph, e::EClass) = find(g, e.id) == e.id

function canonicalize(g::EGraph, n::ENode{T}) where {T}
    if arity(n) > 0
        new_args = map(x -> find(g, x), n.args)
        # return ENode{T}(n.head, new_args, n.proof_src, n.proof_trg, n.age)
        return ENode{T}(n.head, new_args)
    end 
    return n
end

function canonicalize!(g::EGraph, n::ENode)
    for i ∈ 1:arity(n)
        n.args[i] = find(g, n.args[i])
    end
    n.hash[] = UInt(0)
    return n
    # n.args = map(x -> find(g, x), n.args)
end

function canonicalize!(g::EGraph, e::EClass)
    e.id = find(g, e.id)
end

function lookup(g::EGraph, n::ENode)
    cc = canonicalize(g, n)
    if !haskey(g.memo, cc)
        return nothing
    end
    return find(g, g.memo[cc])
end

"""
Inserts an e-node in an [`EGraph`](@ref)
"""
function add!(g::EGraph, n::ENode)::EClass
    @debug("adding ", n)

    n = canonicalize(g, n)
    if haskey(g.memo, n)
        # TODO really override the proof step here?
        eclass = geteclass(g, g.memo[n])
        # for nn in eclass
        #     if n == nn && hasproofdata(n)
        #         # println("MERGING PROOF STEP $nn and $n")
        #         # TODO union!-ing proof data here is BRUTAL. should be ammortized
        #         # keep the older `nn` age
        #         setage!(n, nn.age)
        #         mergeproof!(nn, n)
        #     end
        # end 
        return eclass
    end
    @debug(n, " not found in memo")

    id = push!(g.uf) # create new singleton eclass

    for c_id ∈ n.args
        addparent!(g.classes[c_id], n, id)
    end

    g.memo[n] = id

    classdata = EClass(id, ENode[n], Pair{ENode, EClassId}[])
    g.classes[id] = classdata
    g.numclasses += 1

    for an ∈ g.analyses
        if !islazy(an) && an !== MetadataAnalysis
            setdata!(classdata, an, make(an, g, n))
            modify!(an, g, id)
        end
    end
    return classdata
end

"""
Extend this function on your types to do preliminary
preprocessing of a symbolic term before adding it to 
an EGraph. Most common preprocessing techniques are binarization
of n-ary terms and metadata stripping.
"""
function preprocess(e::Expr) 
    cleanast(e)
end
preprocess(x) = x

"""
Recursively traverse an type satisfying the `TermInterface` and insert terms into an
[`EGraph`](@ref). If `e` has no children (has an arity of 0) then directly
insert the literal into the [`EGraph`](@ref).
"""
# function addexpr!(g::EGraph, se; keepmeta=false, proof_src=nothing)::Tuple{EClass, ENode}
function addexpr!(g::EGraph, se; keepmeta=false, addcall=false)::Tuple{EClass, ENode}
    # println("========== $e ===========")
    if se isa EClass
        return (se, se[1])
    end
    e = preprocess(se)
    T = typeof(e)
    node = nothing

    if isterm(T)
        args = getargs(e)
        if addcall
            args = [gethead(e), args...]
        end
        n = length(args)
        class_ids = Vector{EClassId}(undef, n)
        for i ∈ 1:n
            # println("child $child")
            @inbounds child = args[i]
            c_eclass, c_enode = addexpr!(g, child; keepmeta=keepmeta, addcall=addcall)
            @inbounds class_ids[i] = c_eclass.id
        end
        node = ENode{typeof(e)}((addcall) ? :call : gethead(e), class_ids)
    else 
        node = ENode{typeof(e)}(e, EClassId[])
    end

    # setage!(node, g.age)

    # if !isnothing(proof_src)
    #     rule = first(proof_src)
    #     srcnode = last(proof_src)
    #     if !isnothing(rule) && !isnothing(srcnode)
    #         addproofsrc!(node, rule, srcnode, g.age)
    #     end
    # end

    ec = add!(g, node)
    if keepmeta
        # TODO check if eclass already has metadata?
        meta = TermInterface.metadata(e)
        setdata!(ec, MetadataAnalysis, meta)
    end
    return (ec, node)
end

"""
Given an [`EGraph`](@ref) and two e-class ids, set
the two e-classes as equal.
"""
function Base.merge!(g::EGraph, a::EClassId, b::EClassId)::EClassId
    id_a = find(g, a)
    id_b = find(g, b)

     
    id_a == id_b && return id_a
    to = union!(g.uf, id_a, id_b)

    @debug "merging" id_a id_b

    from = (to == id_a) ? id_b : id_a

    push!(g.dirty, to)

    from_class = g.classes[from]
    to_class = g.classes[to]
    to_class.id = to

    # I (was) the troublesome line!
    g.classes[to] = union!(to_class, from_class)
    delete!(g.classes, from)
    g.numclasses -= 1

    return to
end

function in_same_class(g::EGraph, a, b)
    find(g, a) == find(g, b)
end


# TODO new rebuilding from egg
"""
This function restores invariants and executes
upwards merging in an [`EGraph`](@ref). See
the [egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304)
for more details.
"""
function rebuild!(g::EGraph)
    # normalize!(g.uf)

    while !isempty(g.dirty)
        # todo = unique([find(egraph, id) for id ∈ egraph.dirty])
        todo = unique(g.dirty)
        empty!(g.dirty)
        for x ∈ todo
            repair!(g, x)
        end
    end
    
    if g.root != -1
        g.root = find(g, g.root)
    end
    
    normalize!(g.uf)

    # for i ∈ 1:length(egraph.uf)
    #     find_root!(egraph.uf, i)
    # end
    # INVARIANTS ASSERTIONS
    # for (id, c) ∈  egraph.classes
    #     # ecdata.nodes = map(n -> canonicalize(egraph.uf, n), ecdata.nodes)
    #     println(id, "=>", c.id)
    #     @assert(id == c.id)
    #     # for an ∈ egraph.analyses
    #     #     if haskey(an, id)
    #     #         @assert an[id] == mapreduce(x -> make(an, x), (x, y) -> join(an, x, y), c.nodes)
    #     #     end
    #     # end
    
    #     for n ∈ c
    #         println(n)
    #         println("canon = ", canonicalize(egraph, n))
    #         hr = egraph.memo[canonicalize(egraph, n)]
    #         println(hr)
    #         @assert hr == find(egraph, id)
    #     end
    # end
    # display(egraph.classes); println()
    # @show egraph.dirty

end

function repair!(g::EGraph, id::EClassId)
    id = find(g, id)
    ecdata = geteclass(g, id)
    ecdata.id = id
    @debug "repairing " id

    # for (p_enode, p_eclass) ∈ ecdata.parents
    #     clean_enode!(g, p_enode, find(g, p_eclass))
    # end

    new_parents = (length(ecdata.parents) > 30 ? OrderedDict : LittleDict){ENode,EClassId}()

    for (p_enode, p_eclass) ∈ ecdata.parents
        p_enode = canonicalize!(g, p_enode)
        # deduplicate parents
        if haskey(new_parents, p_enode)
            @debug "merging classes" p_eclass (new_parents[p_enode])
            merge!(g, p_eclass, new_parents[p_enode])
        end
        n_id = find(g, p_eclass)
        g.memo[p_enode] = n_id
        new_parents[p_enode] = n_id 
    end

    ecdata.parents = collect(new_parents)
    @debug "updated parents " id g.parents[id]

    # ecdata.nodes = map(n -> canonicalize(g.uf, n), ecdata.nodes)

    # Analysis invariant maintenance
    for an ∈ g.analyses
        hasdata(ecdata, an) && modify!(an, g, id)
        # modify!(an, id)
        # id = find(g, id)
        for (p_enode, p_id) ∈ ecdata.parents
            # p_eclass = find(g, p_eclass)
            p_eclass = geteclass(g, p_id)
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

    unique!(ecdata.nodes)

    # ecdata.nodes = map(n -> canonicalize(g.uf, n), ecdata.nodes)

end


"""
Recursive function that traverses an [`EGraph`](@ref) and
returns a vector of all reachable e-classes from a given e-class id.
"""
function reachable(g::EGraph, id::EClassId)
    id = find(g, id)
    hist = EClassId[id]
    todo = EClassId[id]
    while !isempty(todo)
        curr = find(g, pop!(todo))
        for n ∈ g.classes[curr]
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
