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

function rec_extract(G::EGraph, an::ExtractionAnalysis, id::Int64)
    # println("extracting from", id)
    # println("class is ", G.M[id])
    (cn, ck) = an[id]
    # println(cn, " ", ck, " ", ariety(cn))
    # println("node is ", cn)
    # cn = canonicalize(G.U, cn)
    # println("canonicalized node is ", cn)
    (ariety(cn) == 0 || ck == Inf) && return cn.sym

    sym = cn.iscall ? :call : cn.sym
    args = map(cn.args) do a
        # TODO evaluate this behaviour
        id == a && (error("loop in extraction"))
        rec_extract(G, an, a)
    end
    args = cn.iscall ? [cn.sym, args...] : args
    return Expr(sym, args...)
end

"""
Given an [`ExtractionAnalysis`](@ref), extract the expression
with the smallest computed cost from an [`EGraph`](@ref)
"""
function extract!(G::EGraph, extran::ExtractionAnalysis)
    println("root is $(G.root)")
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
