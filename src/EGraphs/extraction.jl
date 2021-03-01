"""
A basic cost function, where the computed cost is the size
(number of children) of the current expression.
"""
astsize(n) = 1
astsize(n::Expr) = 1 + length(n.args) - (iscall(n) ? 1 : 0)

"""
A basic cost function, where the computed cost is the size
(number of children) of the current expression, times -1.
Strives to get the largest expression
"""
astsize_inv(n) = -astsize(n)
astsize_inv(n::Expr) = -1 * astsize(n)

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

make(a::ExtractionAnalysis, n) = (n, a.costfun(n))

function make(an::ExtractionAnalysis, n::Expr)
    ncost = an.costfun(n)

    for child_eclass ∈ getfunargs(n)
        !haskey(an, child_eclass) && return (n, Inf)
        if haskey(an, child_eclass) && an[child_eclass] != nothing
            ncost += last(an[child_eclass])
        end
    end

    return (n, ncost)
end

function join(analysis::ExtractionAnalysis, from, to)
    last(from) <= last(to) ? from : to
end

modify!(analysis::ExtractionAnalysis, id::Int64) = nothing

Base.setindex!(an::ExtractionAnalysis, value, id::Int64) =
    setindex!(an.data, value, id)
Base.getindex(an::ExtractionAnalysis, id::Int64) = an.data[id]
Base.haskey(an::ExtractionAnalysis, id::Int64) = haskey(an.data, id)
Base.delete!(an::ExtractionAnalysis, id::Int64) = delete!(an.data, id)


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
    if extran ∈ G.lazy_analyses
        analyze!(G, extran, G.root)
    elseif !(extran ∈ G.analyses)
        error("Extraction analysis is not associated to EGraph")
    end
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
