using MatchCore

macro postequals(G, theory, exprs...)
    @info "Checking equality for " exprs
    G = getfield(__module__, G)
    t = getfield(__module__, theory)


    if length(exprs) == 1; return true end

    ids = []
    for i ∈ exprs
        ec = addexpr!(G, cleanast(i))
        push!(ids, ec.id)
    end

    alleq = () -> (all(x -> in_same_set(G.U, ids[1], x), ids[2:end]))

    @time saturate!(G, t; timeout=6, sizeout=2^12, stopwhen=alleq)

    alleq()
end


# example assuming * operation is always binary

struct NumberFold <: AbstractAnalysis end

function Metatheory.make(analysis::NumberFold, G::EGraph, n)
    data = G.analyses[analysis]
    n isa Number && return n

    if n isa Expr && isexpr(n, :call)
        if n.args[1] == :*
            id_l = n.args[2].id
            id_r = n.args[3].id

            if data[id_l] isa Number && data[id_r] isa Number
                return data[id_l] * data[id_r]
            end
        end
    end
    return nothing
end

function Metatheory.join(analysis::NumberFold, G::EGraph, from, to)
    if from isa Number
        if to isa Number
            @assert from == to
        else return from
        end
    end
    return to
end

function Metatheory.modify!(analysis::NumberFold, G::EGraph, id::Int64)
    data = G.analyses[analysis]
    if data[id] isa Number
        newclass = Metatheory.add!(G, data[id])
        merge!(G, newclass.id, id)
    end
end


comm_monoid = @theory begin
    a * b => b * a
    a * 1 => a
    a * (b * c) => (a * b) * c
end

G = EGraph(:(3 * 4), [NumberFold()])
@testset "Basic Constant Folding Example - Commutative Monoid" begin
    # addanalysis!(G, NumberFold())
    @test (true == @postequals G comm_monoid 3 * 4 12)

    @test (true == @postequals G comm_monoid 3 * 4 12 4*3  6*2)
end


ex = :(a * 3 * b * 4)
G = EGraph(cleanast(ex), [NumberFold()])
@testset "Basic Constant Folding Example 2 - Commutative Monoid" begin
    # addanalysis!(G, NumberFold())
    @test (true == @postequals G comm_monoid (3 * a) * (4 * b) (12*a)*b ((6*2)*b)*a)
end
