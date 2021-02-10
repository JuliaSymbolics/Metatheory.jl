# example assuming * operation is always binary

# ENV["JULIA_DEBUG"] = Metatheory

struct ExtractionAnalysis <: AbstractAnalysis
        costfun::Function
end

# can additionally weigh the function symbol
astsize(n) = 1
astsize(n::Expr) = 1 + length(n.args) - (Meta.isexpr(n, :call) ? 1 : 0)

make(a::ExtractionAnalysis, G::EGraph, n) = (n, a.costfun(n))

function make(analysis::ExtractionAnalysis, G::EGraph, n::Expr)
    data = G.analyses[analysis]

    start = Meta.isexpr(n, :call) ? 2 : 1
    ncost = analysis.costfun(n)

    for cn ∈ n.args[start:end]
        if haskey(data, cn.id) && data[cn.id] != nothing
            ncost += last(data[cn.id])
        end
    end

    return (n, ncost)
end

function join(analysis::ExtractionAnalysis, G::EGraph, from, to)
    last(from) <= last(to) ? from : to
end

modify!(analysis::ExtractionAnalysis, G::EGraph, id::Int64) = nothing

function rec_extract(G::EGraph, data, id::Int64)
    (cn, ck) = data[id]
    !(cn isa Expr) && return cn

    expr = copy(cn)
    start = Meta.isexpr(cn, :call) ? 2 : 1
    expr.args[start:end] = map(expr.args[start:end]) do a
        rec_extract(G, data, a.id)
    end
    return expr
end

extract!(G::EGraph, extran::ExtractionAnalysis) = begin
    rec_extract(G, G.analyses[extran], G.root)
end

extract!(G::EGraph, costfun::Function) = begin
    extran = ExtractionAnalysis(costfun)
    addanalysis!(G, extran)
    rec_extract(G, G.analyses[extran], G.root)
end
