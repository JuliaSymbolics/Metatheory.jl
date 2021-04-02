using MatchCore

comm_monoid = @commutative_monoid (*) 1

fold_mul = @theory begin
	a::Number * b::Number |> a * b
end

t = comm_monoid ∪ fold_mul

@testset "Extraction 1 - Commutative Monoid" begin
    G = EGraph(:(3 * 4))
    saturate!(G, t)
    @test (12 == extract!(G, astsize))

    ex = :(a * 3 * b * 4)
    G = EGraph(cleanast(ex))
	params=SaturationParams(timeout=15)
    saturate!(G, t, params)
    extr = extract!(G, astsize)

	@test extr == :((12 * a) * b) || extr == :(12 * (a * b)) || extr == :(a * (b * 12)) ||
		extr == :((a * b) * 12) || extr == :((12a) * b) || extr == :(a * (12b)) ||
		extr == :((b * (12a))) || extr == :((b * 12) * a) || extr == :((b * a) * 12)
end

fold_add = @theory begin
	a::Number + b::Number |> a + b
end

@testset "Extraction 2" begin
	comm_group = @abelian_group (+) 0 inv


    t = comm_monoid ∪ comm_group ∪ distrib(:(*), :(+)) ∪ fold_mul ∪ fold_add

    # for i ∈ 1:20
    # sleep(0.3)
    ex = cleanast(:((x*(a+b)) + (y*(a+b))))
    G = EGraph(ex)
    saturate!(G, t)
    # end

    extract!(G, astsize) == :((x+y) * (b+a))
end

@testset "Lazy Extraction 2" begin
	comm_group = @abelian_group (+) 0 inv

    t = comm_monoid ∪ comm_group ∪ distrib(:(*), :(+)) ∪ fold_mul ∪ fold_add

    # for i ∈ 1:20
    # sleep(0.3)
    ex = cleanast(:((x*(a+b)) + (y*(a+b))))
    G = EGraph(ex)
    saturate!(G, t)
    # end

    extract!(G, astsize) == :((x+y) * (b+a))
end

@testset "Extraction - Adding analysis after saturation" begin
    G = EGraph(:(3 * 4))
    addexpr!(G, 12)
    saturate!(G, t)
    addexpr!(G, :(a * 2))
    saturate!(G, t)

    saturate!(G, t)

    @test (12 == extract!(G, astsize))

    # for i ∈ 1:100
    ex = :(a * 3 * b * 4)
    G = EGraph(cleanast(ex))
    analyze!(G, NumberFold)
	params=SaturationParams(timeout=15)
    saturate!(G, comm_monoid, params)

    extr = extract!(G, astsize)

	@test extr == :((12 * a) * b) || extr == :(12 * (a * b)) || extr == :(a * (b * 12)) ||
		extr == :((a * b) * 12) || extr == :((12a) * b) || extr == :(a * (12b)) ||
		extr == :((b * (12a))) || extr == :((b * 12) * a) || extr == :((b * a) * 12)
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
	params=SaturationParams(timeout=8)
	saturate!(G, t, params)
	# display(G.classes);println()
	@test extract!(G, astsize) == 1

	G = EGraph(:(log(e) * (log(e) * e^(log(3)))  ))
	params=SaturationParams(timeout=7)
	saturate!(G, t, params)
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

	# TODO could serve as example for more advanced
	# symbolic mathematics simplification based on the computation cost
	# of the expressions
	function cust_astsize(n::ENode, g::EGraph, an::Type{<:AbstractAnalysis})
		cost = 1 + arity(n)

		if n.head == :^
			cost += 2
		end

		for id ∈ n.args
	        eclass = geteclass(g, id)
	        !hasdata(eclass, an) && (cost += Inf; break)
	        cost += last(getdata(eclass, an))
	    end
	    return cost
	end


	@time begin
		G = EGraph(:((log(e) * log(e)) * (log(a^3 * a^2))))
		saturate!(G, t)
		ex = extract!(G, cust_astsize)
	end
	@test ex == :(5*log(a)) || ex == :(log(a)*5)
end

# EXTRACTION BUG!

function costfun(n::ENode, g::EGraph, an)
	arity(n) != 2 && (return 1)
	left = n.args[1]
	left_class = geteclass(g, left)
	ENode(:a) ∈ left_class.nodes ? 1 : 100
end

moveright = @theory begin
    (:b * (:a * c)) => (:a * (:b * c))
end

expr = :(a * (a * (b * (a * b))))
res = rewrite( expr , moveright)

g = EGraph(expr)
saturate!(g, moveright)
resg = extract!(g, costfun)

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

	res = extract!(g, astsize)

	resclassic = rewrite(ex, co)

	@test res == resclassic
end
