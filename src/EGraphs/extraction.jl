"""
A basic cost function, where the computed cost is the size
(number of children) of the current expression.
"""
function astsize(n::ENode, g::EGraph, an::Type{<:AbstractAnalysis})
    cost = 1 + arity(n)
    for id ∈ n.args
        eclass = geteclass(g, id)
        !hasdata(eclass, an) && (cost += Inf; break)
        cost += last(getdata(eclass, an))
    end
    return cost
end

"""
A basic cost function, where the computed cost is the size
(number of children) of the current expression, times -1.
Strives to get the largest expression
"""
function astsize_inv(n::ENode, g::EGraph, an::Type{<:AbstractAnalysis})
    cost = -(1 + arity(n)) # minus sign here is the only difference vs astsize
    for id ∈ n.args
        eclass = geteclass(g, id)
        !hasdata(eclass, an) && (cost += Inf; break)
        cost += last(getdata(eclass, an))
    end
    return cost
end

"""
An [`AbstractAnalysis`](@ref) that computes the cost of expression nodes
and chooses the node with the smallest cost for each E-Class.
This abstract type is parametrised by a function F.
This is useful for the analysis storage in [`EClass`](@ref)
"""
abstract type ExtractionAnalysis{F} <: AbstractAnalysis end

make(a::Type{ExtractionAnalysis{F}}, g::EGraph, n::ENode) where F = (n, F(n, g, a))

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
    (!isterm(termtype(cn)) || ck == Inf) && return cn.head

    extractnode(g, cn, an; eclass=eclass)
end

function extractnode(g::EGraph, n::ENode, an::Type{<:ExtractionAnalysis}; eclass=nothing)
    children = map(n.args) do a
        rec_extract(g, an, a)
    end
    
    meta = nothing
    if !isnothing(eclass)
        meta = getdata(eclass, MetadataAnalysis, nothing)
    end
    T = termtype(n)
    if iscall(T) # && n.head == :call
        return similarterm(T, children[1], children[2:end]; metadata = meta)            
    end
    similarterm(T, n.head, children; metadata = meta)
end

# TODO CUSTOMTYPES document how to for custom types
# TODO maybe extractor can just be the array of extracted children?
function extractnode(g::EGraph, n::ENode{Expr}, extractor::Function)::Expr
    return Expr(n.head, map(extractor, n.args)...)
end

function extractnode(g::EGraph, n::ENode{T}, extractor::Function) where T
    if arity(n) > 0
        error("ENode extraction is not defined for non-literal type $T")
    end
    return n.head
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
