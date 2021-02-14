using MatchCore

comm_monoid = @commutative_monoid (*) 1

fold_mul = @theory begin
	a::Number * b::Number |> a * b
end

t = comm_monoid ∪ fold_mul

extran = ExtractionAnalysis(astsize)


@testset "Extraction 1 - Commutative Monoid" begin
    G = EGraph(:(3 * 4), [extran])
    saturate!(G, t)
    @test (12 == extract!(G, extran))

    ex = :(a * 3 * b * 4)
    G = EGraph(cleanast(ex), [extran])
    saturate!(G, t)
    extr = extract!(G, extran)
	# println(extr)

    @test extr == :(12 * (a * b))
end


@testset "Extraction 2" begin
	comm_group = @abelian_group (+) 0 inv

	fold_add = @theory begin
		a::Number + b::Number |> a + b
	end
    t = comm_monoid ∪ comm_group ∪ distrib(:(*), :(+)) ∪ fold_mul ∪ fold_add

    # for i ∈ 1:20
    # sleep(0.3)
    ex = cleanast(:((x*(a+b)) + (y*(a+b))))
    G = EGraph(ex, [extran])
    saturate!(G, t)
    # end

    extract!(G, extran) == :((x+y) * (b+a))
end

@testset "Extraction - Adding analysis after saturation" begin
    G = EGraph(:(3 * 4))
    addexpr!(G, 12)
    saturate!(G, t)
    addexpr!(G, :(a * 2))
    saturate!(G, t)

    addanalysis!(G, extran)
    saturate!(G, t)

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

comm_monoid = @commutative_monoid (*) 1

comm_group = @abelian_group (+) 0 inv

powers = @theory begin
	a * a => a^2
	a => a^1
	a^n * a^m => a^(n+m)
end
logids = @theory begin
	log(a^n) => n * log(a)
	log(x * y) => log(x) * log(y)
	log(1) => 0
	log(:e) => 1
	:e^(log(x)) => x
end
fold_add = @theory begin
	a::Number + b::Number |> a + b
end


t = comm_monoid ∪ comm_group ∪ distrib(:(*), :(+)) ∪ powers ∪ logids ∪ fold_mul ∪ fold_add

@testset "Complex Extraction" begin
	G = EGraph(:(log(e) * log(e)))
	saturate!(G, t)
	@test extract!(G, astsize) == 1

	G = EGraph(:(log(e) * (log(e) * e^(log(3)))  ))
	saturate!(G, t)
	@test extract!(G, astsize) == 3

	@time begin
		G = EGraph(:(a^3 * a^2))
		saturate!(G, t)
		ex = extract!(G, astsize)
	end
	@test ex == :(a^5)

	@time begin
		G = EGraph(:(a^3 * a^2))
		saturate!(G, t)
		ex = extract!(G, astsize)
	end
	@test ex == :(a^5)

	@time begin
		G = EGraph(:((log(e) * log(e)) * (log(a^3 * a^2))))
		saturate!(G, t)
		ex = extract!(G, astsize)
	end
	@test ex == :(5log(a))
end
