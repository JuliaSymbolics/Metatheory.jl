using MatchCore

# example assuming * operation is always binary

# ENV["JULIA_DEBUG"] = Metatheory

struct ExtractionAnalysis <: AbstractAnalysis
        costfun::Function
end

# can additionally weigh the function symbol
astsize(n) = 1
astsize(n::Expr) = 1 + length(n.args) - (Meta.isexpr(n, :call) ? 1 : 0)

Metatheory.make(a::ExtractionAnalysis, G::EGraph, n) = (n, a.costfun(n))

function Metatheory.make(analysis::ExtractionAnalysis, G::EGraph, n::Expr)
    data = G.analyses[analysis]

    start = Meta.isexpr(n, :call) ? 2 : 1
    ncost = analysis.costfun(n)

    expr = copy(n)
    expr.args[start:end] = map(expr.args[start:end]) do cn
        (ce, ck) = data[cn.id]
        ncost += ck
        return ce
    end

    return (expr, ncost)
end

function Metatheory.join(analysis::ExtractionAnalysis, G::EGraph, from, to)
    last(from) < last(to) ? from : to
end

Metatheory.modify!(analysis::ExtractionAnalysis, G::EGraph, id::Int64) = nothing

extract(G::EGraph, extran) = begin
    # Metatheory.analysisfix(extran, G, G.root)
    G.analyses[extran][G.root] |> first
end

comm_monoid = @theory begin
    a * b => b * a
    a * 1 => a
    a * (b * c) => (a * b) * c
end

extran = ExtractionAnalysis(astsize)

@testset "Extraction 1 - Commutative Monoid" begin
    G = EGraph(:(3 * 4), [NumberFold(), extran])
    saturate!(G, comm_monoid)
    @test (12 == extract(G, extran))

    ex = :(a * 3 * b * 4)
    G = EGraph(cleanast(ex), [NumberFold(), extran])
    saturate!(G, comm_monoid)
    extr = extract(G, extran)
    # TODO wtf why is this not always the same result
    @test areequal(comm_monoid, extr, :(b*12a))
end


# TODO broken

# @testset "Extraction - Adding analysis after saturation" begin
#     G = EGraph(:(3 * 4))
#     addexpr!(G, 12)
#     saturate!(G, comm_monoid)
#     addexpr!(G, :(a * 2))
#     addanalysis!(G, NumberFold())
#     saturate!(G, comm_monoid)
#
#     addanalysis!(G, extran)
#     saturate!(G, comm_monoid)
#
#     @test (12 == extract(G, extran))
#
#     ex = :(a * 3 * b * 4)
#     G = EGraph(cleanast(ex))
#     addanalysis!(G, NumberFold())
#     addanalysis!(G, extran)
#     saturate!(G, comm_monoid)
#
#     extr = extract(G, extran)
#     @test areequal(comm_monoid, extr, :(b*12a))
# end
