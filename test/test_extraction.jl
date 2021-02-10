using MatchCore



comm_monoid = @theory begin
    a * b => b * a
    a * 1 => a
    a * (b * c) => (a * b) * c
end

extran = ExtractionAnalysis(astsize)


@testset "Extraction 1 - Commutative Monoid" begin
    G = EGraph(:(3 * 4), [NumberFold(), extran])
    saturate!(G, comm_monoid)
    @test (12 == extract!(G, extran))

    ex = :(a * 3 * b * 4)
    G = EGraph(cleanast(ex), [NumberFold(), extran])
    saturate!(G, comm_monoid)
    extr = extract!(G, extran)
	# println(extr)

    @test extr == :(12 * (a * b))
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

    # for i ∈ 1:20
    # sleep(0.3)
    ex = cleanast(:((x*(a+b)) + (y*(a+b))))
    G = EGraph(ex, [NumberFold(), extran])
    saturate!(G, t)
    # end

    extract!(G, extran) == :((x+y) * (b+a))
end

@testset "Extraction - Adding analysis after saturation" begin
    G = EGraph(:(3 * 4))
    addexpr!(G, 12)
    saturate!(G, comm_monoid)
    addexpr!(G, :(a * 2))
    addanalysis!(G, NumberFold())
    saturate!(G, comm_monoid)

    addanalysis!(G, extran)
    saturate!(G, comm_monoid)

    @test (12 == extract!(G, extran))

    # for i ∈ 1:100
    sleep(0.2)
    ex = :(a * 3 * b * 4)
    G = EGraph(cleanast(ex))
    addanalysis!(G, NumberFold())
    addanalysis!(G, extran)
    saturate!(G, comm_monoid)

    extr = extract!(G, extran)
    # end

    @test extr == :(12 * (a * b))
end

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
powers = @theory begin
	a * a => a^2
end
logids = @theory begin
	log(a^n) => n * log(a)
	log(x * y) => log(x) * log(y)
	log(1) => 0
	log(:e) => 1
	:e^(log(x)) => x
end

t = comm_monoid ∪ comm_group ∪ distrib ∪ powers ∪ logids

@testset "Complex Extraction" begin
	G = EGraph(:(log(e) * log(e)))
	saturate!(G, t)
	@test extract!(G, astsize) == 1
end
