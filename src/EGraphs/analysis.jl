"""
    islazy(an::Type{<:AbstractAnalysis})

Should return `true` if the EGraph Analysis `an` is lazy
and false otherwise. A *lazy* EGraph Analysis is computed 
only when [analyze!](@ref) is called. *Non-lazy* 
analyses are instead computed on-the-fly every time ENodes are added to the EGraph or
EClasses are merged.  
"""
islazy(an::Type{<:AbstractAnalysis})::Bool = false

"""
    modify!(an::Type{<:AbstractAnalysis}, g, id)

The `modify!` function for EGraph Analysis can optionally modify the eclass
`g[id]` after it has been analyzed, typically by adding an ENode.
It should be **idempotent** if no other changes occur to the EClass. 
(See the [egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304)).
"""
modify!(analysis::Type{<:AbstractAnalysis}, g, id) = nothing


"""
    join(an::Type{<:AbstractAnalysis}, a, b)

Joins two analyses values into a single one, used by [analyze!](@ref)
when two eclasses are being merged or the analysis is being constructed.
"""
join(analysis::Type{<:AbstractAnalysis}, a, b) = 
    error("Analysis does not implement join") 

"""
    make(an::Type{<:AbstractAnalysis}, g, n)

Given an ENode `n`, `make` should return the corresponding analysis value. 
"""
make(analysis::Type{<:AbstractAnalysis}, g, n) = 
    error("Analysis does not implement make")


# TODO default analysis for metadata here
abstract type MetadataAnalysis <: AbstractAnalysis end

analyze!(g::EGraph, an::Type{<:AbstractAnalysis}, id::EClassId) = analyze!(g, an, reachable(g, id))
analyze!(g::EGraph, an::Type{<:AbstractAnalysis}) = analyze!(g, an, collect(keys(g.classes)))


"""
    analyze!(egraph, analysis, [ECLASS_IDS])

Given an [EGraph](@ref) and an `analysis` of type `<:AbstractAnalysis`, 
do an automated bottom up trasversal of the EGraph, associating a value from the 
domain of `analysis` to each ENode in the egraph by the [make](@ref) function. 
Then, for each [EClass](@ref), compute the [join](@ref) of the children ENodes analyses values.
After `analyze!` is called, an analysis value will be associated to each EClass in the EGraph.
One can inspect and retrieve analysis values by using [hasdata](@ref) and [getdata](@ref).   
Note that an [EGraph](@ref) can only contain one analysis of type `an`.
"""
function analyze!(g::EGraph, an::Type{<:AbstractAnalysis}, ids::Vector{EClassId})
    push!(g.analyses, an)
    ids = sort(ids)
    # @assert isempty(g.dirty)

    did_something = true
    while did_something
        did_something = false

        for id ∈ ids
            eclass = g[id]
            id = eclass.id
            pass = mapreduce(x -> make(an, g, x), (x, y) -> join(an, x, y), eclass)
            # pass = make_pass(G, analysis, find(G,id))

            # if pass !== missing
            if !isequal(pass, getdata(eclass, an, missing))
                setdata!(eclass, an, pass)
                did_something = true
                push!(g.dirty, id)
            end
        end
    end

    for id ∈ ids
        eclass = g[id]
        id = eclass.id
        if !hasdata(eclass, an)
            error("failed to compute analysis for eclass ", id)
        end
    end

    return true
end

"""
A basic cost function, where the computed cost is the size
(number of children) of the current expression.
"""
function astsize(n::ENodeTerm, g::EGraph, an::Type{<:AbstractAnalysis})
    cost = 1 + arity(n)
    for id ∈ arguments(n)
        eclass = g[id]
        !hasdata(eclass, an) && (cost += Inf; break)
        cost += last(getdata(eclass, an))
    end
    return cost
end

astsize(n::ENodeLiteral, g::EGraph, an::Type{<:AbstractAnalysis}) = 1

"""
A basic cost function, where the computed cost is the size
(number of children) of the current expression, times -1.
Strives to get the largest expression
"""
function astsize_inv(n::ENodeTerm, g::EGraph, an::Type{<:AbstractAnalysis})
    cost = -(1 + arity(n)) # minus sign here is the only difference vs astsize
    for id ∈ arguments(n)
        eclass = g[id]
        !hasdata(eclass, an) && (cost += Inf; break)
        cost += last(getdata(eclass, an))
    end
    return cost
end

astsize_inv(n::ENodeLiteral, g::EGraph, an::Type{<:AbstractAnalysis}) = -1


"""
An [`AbstractAnalysis`](@ref) that computes the cost of expression nodes
and chooses the node with the smallest cost for each E-Class.
This abstract type is parametrised by a function F.
This is useful for the analysis storage in [`EClass`](@ref)
"""
abstract type ExtractionAnalysis{F} <: AbstractAnalysis end

make(a::Type{ExtractionAnalysis{F}}, g::EGraph, n::AbstractENode) where F = (n, F(n, g, a))

join(a::Type{<:ExtractionAnalysis}, from, to) = last(from) <= last(to) ? from : to

islazy(a::Type{<:ExtractionAnalysis}) = true

function rec_extract(g::EGraph, an::Type{<:ExtractionAnalysis}, id::EClassId; simterm=similarterm)
    eclass = g[id]
    anval = getdata(eclass, an, missing)
    if anval === missing 
        analyze!(g, an, id)
        anval = getdata(eclass, an)
    end
    (cn, ck) = anval
    ck == Inf && error("Infinite cost when extracting enode")

    extractnode(g, eclass, cn, an; simterm=simterm)
end

function extractnode(g::EGraph, eclass::EClass, n::ENodeTerm, an::Type{<:ExtractionAnalysis}; simterm=similarterm)
    children = map(arguments(n)) do a
        rec_extract(g, an, a; simterm=simterm)
    end
    
    meta = getdata(eclass, MetadataAnalysis, nothing)
    T = termtype(n)
    similarterm(T, operation(n), children; metadata=meta, exprhead=exprhead(n));
end

function extractnode(g::EGraph, eclass::EClass, n::ENodeLiteral, an::Type{<:ExtractionAnalysis}; simterm=similarterm)
    n.value
end


"""
Given an [`ExtractionAnalysis`](@ref), extract the expression
with the smallest computed cost from an [`EGraph`](@ref)
"""
function extract!(g::EGraph, a::Type{ExtractionAnalysis{F}} where F; root=-1, simterm=similarterm)
    if root == -1
        root = g.root
    end
    analyze!(g, a, root)
    !(a ∈ g.analyses) && error("Extraction analysis is not associated to EGraph")
    rec_extract(g, a, root; simterm=simterm)
end

"""
Given a cost function, extract the expression
with the smallest computed cost from an [`EGraph`](@ref)
"""
function extract!(g::EGraph, costfun::Function; root=-1, simterm=similarterm)
    extran = ExtractionAnalysis{costfun}
    extract!(g, extran; root=root)
end

macro extract(expr, theory, costfun)
    quote
        let g = EGraph($expr)
            saturate!(g, $theory)
            ex = extract!(g, $costfun)
            (g, ex)
        end
    end |> esc
end
