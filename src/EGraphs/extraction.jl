"""
A basic cost function, where the computed cost is the size
(number of children) of the current expression.
"""
function astsize(n::ENode, an::AbstractAnalysis)
    cost = 1 + ariety(n)
    for a ∈ n.args
        !haskey(an, a) && (cost += Inf; break)
        cost += last(an[a])
    end
    return cost
end

"""
A basic cost function, where the computed cost is the size
(number of children) of the current expression, times -1.
Strives to get the largest expression
"""
astsize_inv(n::ENode, an::AbstractAnalysis) = -1 * astsize(n, an)

const CostData = Dict{Int64, Tuple{ENode, Number}}

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

make(a::ExtractionAnalysis, n::ENode) = (n, a.costfun(n, a))

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

function rec_extract(g::EGraph, an::ExtractionAnalysis, id::Int64)
    (cn, ck) = an[id]
    (ariety(cn) == 0 || ck == Inf) && return cn.head
    extractor = a -> rec_extract(g, an, a)
    extractnode(cn, extractor)
end

# TODO document how to extract
function extractnode(n::ENode{Expr}, extractor::Function)::Expr
    expr_args = []
    expr_head = n.head

    if n.metadata.iscall
        push!(expr_args, n.head)
        expr_head = :call
    end

    for a ∈ n.args
        # id == a && (error("loop in extraction"))
        push!(expr_args, extractor(a))
    end

    return Expr(expr_head, expr_args...)
end

function extractnode(n::ENode, extractor::Function) where T
    if ariety(n) > 0
        error("ENode extraction is not defined for non-literal type $T")
    end
    return n.head
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
