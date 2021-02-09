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

    for cn ∈ n.args[start:end]
        if haskey(data, cn.id)
            ncost += last(data[cn.id])
        end
    end

    return (n, ncost)
end

function Metatheory.join(analysis::ExtractionAnalysis, G::EGraph, from, to)
    last(from) < last(to) ? from : to
end

Metatheory.modify!(analysis::ExtractionAnalysis, G::EGraph, id::Int64) = nothing

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

extract(G::EGraph, extran) = begin
    rec_extract(G, G.analyses[extran], G.root)
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
    @test extr == :((12a) * b) || extr == :(b * (12a)) ||
        extr == :((a*12) * b) || extr == :(b * (a*12))
end


@testset "Extraction 2" begin
    comm_group = @theory begin
        a + 0 => a
        a + b => b + a
        a + inv(a) => 0 # inverse
        a + (b + c) => (a + b) + c
    end
    distrib = @theory begin
        a * (b + c) => (a * b) + (a * c)
        (a * b) + (a * c) => a * (b + c)
    end
    t = comm_monoid ∪ comm_group ∪ distrib

    ex = cleanast(:((x*(a+b)) + (y*(a+b))))
    G = EGraph(ex, [NumberFold(), extran])
    saturate!(G, t)
    @test extract(G, extran) ∈ [
        :((a + b) * (x + y)), :((a + b) * (y + x)),
        :((b + a) * (x + y)), :((b + a) * (y + x)),
        :((x + y) * (a + b)), :((x + y) * (b + a)),
        :((y + x) * (b + a)), :((y + x) * (a + b))]
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
