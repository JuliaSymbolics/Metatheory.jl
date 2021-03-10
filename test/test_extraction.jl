using MatchCore

comm_monoid = @commutative_monoid (*) 1

fold_mul = @theory begin
	a::$Number * b::$Number |> a * b
end

t = comm_monoid ∪ fold_mul

@testset "Extraction 1 - Commutative Monoid" begin
    G = EGraph(:(3 * 4))
	extran = addanalysis!(G, ExtractionAnalysis, astsize)
    saturate!(G, t)
    @test (12 == extract!(G, extran))

    ex = :(a * 3 * b * 4)
    G = EGraph(cleanast(ex))
	extran = addanalysis!(G, ExtractionAnalysis, astsize)
    saturate!(G, t; timeout=15)
	display(G.M); println()
    extr = extract!(G, extran)
	println(extr)

    @test extr == :(b * (a * 12)) || extr == :((b * 12) * a) || extr == :(a * (b * 12)) ||
		extr == :((a * b) * 12) || extr == :((12a) * b)
end

fold_add = @theory begin
	a::$Number + b::$Number |> a + b
end

@testset "Extraction 2" begin
	comm_group = @abelian_group (+) 0 inv


    t = comm_monoid ∪ comm_group ∪ distrib(:(*), :(+)) ∪ fold_mul ∪ fold_add

    # for i ∈ 1:20
    # sleep(0.3)
    ex = cleanast(:((x*(a+b)) + (y*(a+b))))
    G = EGraph(ex)
	extran = addanalysis!(G, ExtractionAnalysis, astsize)
    saturate!(G, t)
    # end

    extract!(G, extran) == :((x+y) * (b+a))
end

@testset "Lazy Extraction 2" begin
	comm_group = @abelian_group (+) 0 inv

    t = comm_monoid ∪ comm_group ∪ distrib(:(*), :(+)) ∪ fold_mul ∪ fold_add

    # for i ∈ 1:20
    # sleep(0.3)
    ex = cleanast(:((x*(a+b)) + (y*(a+b))))
    G = EGraph(ex)
	extran = addanalysis!(G, ExtractionAnalysis, astsize)
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

    extran = addanalysis!(G, ExtractionAnalysis, astsize)
    saturate!(G, t)

    @test (12 == extract!(G, extran))

    # for i ∈ 1:100
    ex = :(a * 3 * b * 4)
    G = EGraph(cleanast(ex))
    addanalysis!(G, NumberFold)
    extran = addanalysis!(G, ExtractionAnalysis, astsize)
    saturate!(G, comm_monoid; timeout=15)

    extr = extract!(G, extran)
	println(extr)

    @test extr == :((12 * a) * b) || extr == :(12 * (a * b)) || extr == :(a * (b * 12)) ||
		extr == :((a * b) * 12) || extr == :((12a) * b)
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

t = comm_monoid ∪ comm_group ∪ distrib(:(*), :(+)) ∪ powers ∪ logids  ∪ fold_mul ∪ fold_add

@testset "Complex Extraction" begin
	G = EGraph(:(log(e) * log(e)))
	extran = addanalysis!(G, ExtractionAnalysis, astsize)
	saturate!(G, t; timeout=7)
	@test extract!(G, extran) == 1

	G = EGraph(:(log(e) * (log(e) * e^(log(3)))  ))
	extran = addanalysis!(G, ExtractionAnalysis, astsize)
	saturate!(G, t; timeout=7)
	@test extract!(G, extran) == 3

	@time begin
		G = EGraph(:(a^3 * a^2))
		extran = addanalysis!(G, ExtractionAnalysis, astsize)
		saturate!(G, t; timeout=7)
		ex = extract!(G, extran)
	end
	@test ex == :(a^5)

	@time begin
		G = EGraph(:(a^3 * a^2))
		extran = addanalysis!(G, ExtractionAnalysis, astsize)
		saturate!(G, t; timeout=7)
		ex = extract!(G, extran)
	end
	@test ex == :(a^5)

	cust_astsize(n, an) = 1
	function cust_astsize(n::Expr, an)
		nc = astsize(n, an)
		if getfunsym(n) == :(^)
			nc = nc + 2
		end
		nc
	end


	@time begin
		G = EGraph(:((log(e) * log(e)) * (log(a^3 * a^2))))
		extran = addanalysis!(G, ExtractionAnalysis, cust_astsize)
		saturate!(G, t; timeout=8)
		ex = extract!(G, extran)
	end
	println(ex)
	@test ex == :(5*log(a)) || ex == :(log(a)*5)
end

# EXTRACTION BUG!

costfun(n, an) = 1
function costfun(n::Expr, an)
	left = n.args[2]

	println(n)
	:a ∈ g.M[left.id].nodes ? 1 : 100
end

moveright = @theory begin
    (:b * (:a * c)) => (:a * (:b * c))
end

expr = :(a * (a * (b * (a * b))))
res = rewrite( expr , moveright)
println(res)

g = EGraph(expr)
saturate!(g, moveright)
extractor = addanalysis!(g, ExtractionAnalysis, costfun)
resg = extract!(g, extractor)
display(g.M); println(); println(g.root)
display(extractor.data); println()

println(resg)

@testset "Symbols in Right hand" begin
    @test resg == res == :(a * (a * (a * (b * b))))
end

co = @theory begin
	foo(x ⋅ :bazoo ⋅ :woo) => Σ(:n * x)
end
@testset "Consistency with Matchcore backend" begin
	ex = :(foo(wa(rio) ⋅ bazoo ⋅ woo))
	g = EGraph(ex)
	saturate!(g, co)
	extran = addanalysis!(g, ExtractionAnalysis, astsize)

	display(g.M); println()
	res = extract!(g, extran)

	resclassic = rewrite(ex, co)

	@test res == resclassic
end
