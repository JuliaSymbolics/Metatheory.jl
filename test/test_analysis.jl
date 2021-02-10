using MatchCore

# example assuming * operation is always binary

# ENV["JULIA_DEBUG"] = Metatheory

struct NumberFold <: AbstractAnalysis end

function Metatheory.make(analysis::NumberFold, G::EGraph, n)
    data = G.analyses[analysis]
    n isa Number && return n

    if n isa Expr && Meta.isexpr(n, :call)
        if n.args[1] == :*
            id_l = n.args[2].id
            id_r = n.args[3].id

            # if haskey(data, id_l) && haskey(data, id_r) &&
                data[id_l] isa Number && data[id_r] isa Number &&
                return data[id_l] * data[id_r]
            # end
        elseif n.args[1] == :+
            id_l = n.args[2].id
            id_r = n.args[3].id

            # if haskey(data, id_l) && haskey(data, id_r) &&
                data[id_l] isa Number && data[id_r] isa Number &&
                return data[id_l] + data[id_r]
            # end
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
    @test (true == @areequalg G comm_monoid 3 * 4 12)

    @test (true == @areequalg G comm_monoid 3 * 4 12 4*3  6*2)
end


@testset "Basic Constant Folding Example 2 - Commutative Monoid" begin
    ex = :(a * 3 * b * 4)
    G = EGraph(cleanast(ex), [NumberFold()])
    @test (true == @areequalg G comm_monoid (3 * a) * (4 * b) (12*a)*b ((6*2)*b)*a)
end

@testset "Basic Constant Folding Example - Adding analysis after saturation" begin
    G = EGraph(:(3 * 4))
    addexpr!(G, 12)
    saturate!(G, comm_monoid)
    addexpr!(G, :(a * 2))
    addanalysis!(G, NumberFold())
    saturate!(G, comm_monoid)
    # display(G.M); println()

    @test (true == areequal(G, comm_monoid, :(3 * 4), 12, :(4*3), :(6*2)))

    ex = :(a * 3 * b * 4)
    G = EGraph(cleanast(ex))
    addanalysis!(G, NumberFold())
    @test (true == areequal(G, comm_monoid, :((3 * a) * (4 * b)), :((12*a)*b),
        :(((6*2)*b)*a)))
end
