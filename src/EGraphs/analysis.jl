
# TODO document AbstractAnalysis

# modify!(analysis::Type{<:AbstractAnalysis}, eclass::EClass) =
#     error("Analysis does not implement modify!")
islazy(an::Type{<:AbstractAnalysis})::Bool = false
modify!(analysis::Type{<:AbstractAnalysis}, g, id) = nothing
join(analysis::Type{<:AbstractAnalysis}, a, b) =
    error("Analysis does not implement join")
make(analysis::Type{<:AbstractAnalysis}, g, a) =
    error("Analysis does not implement make")


# TODO default analysis for metadata here
abstract type MetadataAnalysis <: AbstractAnalysis end

analyze!(g::EGraph, an::Type{<:AbstractAnalysis}, id::EClassId) =
    analyze!(g, an, reachable(g, id))


function analyze!(g::EGraph, an::Type{<:AbstractAnalysis})
    analyze!(g, an, collect(keys(g.classes)))
end

"""

**WARNING**. This function is unstable.
An [`EGraph`](@ref) can only contain one analysis of type `an`.
"""
function analyze!(g::EGraph, an::Type{<:AbstractAnalysis}, ids::Vector{EClassId})
    push!(g.analyses, an)
    ids = sort(ids)
    # @assert isempty(g.dirty)

    did_something = true
    while did_something
        did_something = false

        for id ∈ ids
            eclass = geteclass(g, id)
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
        eclass = geteclass(g, id)
        id = eclass.id
        if !hasdata(eclass, an)
            # display(g.classes[id]); println()
            # display(analysis.data); println()
            error("failed to compute analysis for eclass ", id)
        end
    end

    # rebuild!(g)

    # display(analysis.data); println()

    return true
end

"""
A basic cost function, where the computed cost is the size
(number of children) of the current expression.
"""
function astsize(n::ENodeTerm, g::EGraph, an::Type{<:AbstractAnalysis})
    cost = 1 + arity(n)
    for id ∈ arguments(n)
        eclass = geteclass(g, id)
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
        eclass = geteclass(g, id)
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

function rec_extract(g::EGraph, an::Type{<:ExtractionAnalysis}, id::EClassId)
    eclass = geteclass(g, id)
    anval = getdata(eclass, an, missing)
    if anval === missing 
        analyze!(g, an, id)
        anval = getdata(eclass, an)
    end
    (cn, ck) = anval
    (!istree(termtype(cn)) || ck == Inf) && return operation(cn)

    extractnode(g, cn, an; eclass=eclass)
end

function extractnode(g::EGraph, n::ENodeTerm, an::Type{<:ExtractionAnalysis}; eclass=nothing)
    children = map(arguments(n)) do a
        rec_extract(g, an, a)
    end
    
    meta = nothing
    if !isnothing(eclass)
        meta = getdata(eclass, MetadataAnalysis, nothing)
    end
    T = termtype(n)
    similarterm(T, operation(n), children; metadata=meta, exprhead=exprhead(n));
end

function extractnode(g::EGraph, n::ENodeLiteral, an::Type{<:ExtractionAnalysis}; eclass=nothing)
    n.value
end


"""
Given an [`ExtractionAnalysis`](@ref), extract the expression
with the smallest computed cost from an [`EGraph`](@ref)
"""
function extract!(g::EGraph, a::Type{ExtractionAnalysis{F}} where F; root=-1)
    # @show root g.root
    if root == -1
        root = g.root
    end
    # @show root g.root
    analyze!(g, a, root)
    !(a ∈ g.analyses) && error("Extraction analysis is not associated to EGraph")
    rec_extract(g, a, root)
end

"""
Given a cost function, extract the expression
with the smallest computed cost from an [`EGraph`](@ref)
"""
function extract!(g::EGraph, costfun::Function; root=-1)
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
