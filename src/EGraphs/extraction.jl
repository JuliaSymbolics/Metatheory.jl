"""
A basic cost function, where the computed cost is the size
(number of children) of the current expression.
"""
astsize(n, an::AbstractAnalysis) = 1
function astsize(n::Expr, an::AbstractAnalysis)
    args = getfunargs(n)
    cost = 1 + length(args)

    for child_eclass ∈ args
        !haskey(an, child_eclass) && return Inf
        if haskey(an, child_eclass) && an[child_eclass] != nothing
            cost += last(an[child_eclass])
        end
    end
    return cost
end

"""
A basic cost function, where the computed cost is the size
(number of children) of the current expression, times -1.
Strives to get the largest expression
"""
astsize_inv(n, an::AbstractAnalysis) = -astsize(n, an)
astsize_inv(n::Expr, an::AbstractAnalysis) = -1 * astsize(n, an)

const CostData = Dict{Int64, Tuple{Any, Number}}

"""
An [`AbstractAnalysis`](@ref) that computes the cost of expression nodes
and chooses the node with the smallest cost for each E-Class.
"""
struct ExtractionAnalysis <: AbstractAnalysis
    egraph::EGraph
    costfun::Function
    data::CostData
end

ExtractionAnalysis(g::EGraph, costfun::Function) =
    ExtractionAnalysis(g, costfun, CostData())

make(a::ExtractionAnalysis, n) = (n, a.costfun(n, a))

function join(analysis::ExtractionAnalysis, from, to)
    last(from) <= last(to) ? from : to
end

modify!(analysis::ExtractionAnalysis, id::Int64) = nothing

Base.setindex!(an::ExtractionAnalysis, value, id::Int64) =
    setindex!(an.data, value, id)
Base.getindex(an::ExtractionAnalysis, id::Int64) = an.data[id]
Base.haskey(an::ExtractionAnalysis, id::Int64) = haskey(an.data, id)
Base.delete!(an::ExtractionAnalysis, id::Int64) = delete!(an.data, id)
islazy(an::ExtractionAnalysis) = true

function rec_extract(G::EGraph, an::ExtractionAnalysis, id::Int64)
    (cn, ck) = an[id]
    (!(cn isa Expr) || ck == Inf) && return cn

    expr = copy(cn)
    setfunargs!(expr, getfunargs(expr) .|> a -> rec_extract(G, an, a.id))
    return expr
end

"""
Given an [`ExtractionAnalysis`](@ref), extract the expression
with the smallest computed cost from an [`EGraph`](@ref)
"""
function extract!(G::EGraph, extran::ExtractionAnalysis)
    islazy(extran) && analyze!(G, extran, G.root)
    !(extran ∈ G.analyses) && error("Extraction analysis is not associated to EGraph")
    rec_extract(G, extran, G.root)
end

macro extract(expr, theory, costfun)
    quote
        let g = EGraph($expr)
            saturate!(g, $theory)
            extran = addanalysis!(g, ExtractionAnalysis, $costfun)
            ex = extract!(g, extran)
            (g, ex)
        end
    end |> esc
end
