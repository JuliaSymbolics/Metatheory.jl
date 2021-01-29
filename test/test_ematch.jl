macro equals(theory, exprs...)
    t = getfield(__module__, theory)

    if length(exprs) == 1; return true end

    G = EGraph()
    ids = []
    for i ∈ exprs
        ec = addexpr!(G, i)
        push!(ids, ec.id)
    end
    @time saturate!(G, t; timeout=10)

    all(x -> in_same_set(G.U, ids[1], x), ids[2:end])
end

r = @theory begin
    foo(x,y) => 2*x%y
    foo(x,y) => sin(x)
    sin(x) => foo(x,x)
end
@testset "Basic Equalities 1" begin
    @test (@equals r foo(b,c) foo(d,d)) == false
end


comm_monoid = @theory begin
    a * b => b * a
    a * 1 => a
    a * (b * c) => (a * b) * c
end
@testset "Basic Equalities - Commutative Monoid" begin
    @test true == (@equals comm_monoid a*(c*(1*d)) c*(1*(d*a)) )
    @test true == (@equals comm_monoid x*y y*x )
    @test true == (@equals comm_monoid (x*x)*(x * 1) x*(x*x) )
end


comm_group = @theory begin
    a + 0 => a
    a + b => b + a
    a + inv(a) => 0 # inverse
    a + (b + c) => (a + b) + c
end
distrib = @theory begin
    a * (b + c) => (a * b) + (a * c)
end
t = comm_monoid ∪ comm_group ∪ distrib
@testset "Basic Equalities - Comm. Monoid, Abelian Group, Distributivity" begin
    @test true == (@equals t (a * b) + (a * c) a*(b+c) )
    @test true == (@equals t a*(c*(1*d)) c*(1*(d*a)) )
    @test true == (@equals t a+(b*(c*d)) ((d*c)*b)+a )
    @test true == (@equals t (x+y)*(a+b) ((a*(x+y)) + b*(x+y)) ((x*(a+b)) + y*(a+b)) )
    @test true == (@equals t (((x*a + x*b) + y*a) + y*b) (x+y)*(a+b) )
    @test true == (@equals t a+(b*(c*d)) ((d*c)*b)+a )
    @test true == (@equals t a+inv(a) 0 (x*y)+inv(x*y) 1*0 )
end
