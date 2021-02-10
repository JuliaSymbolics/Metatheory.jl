r = @theory begin
    foo(x,y) => 2*x%y
    foo(x,y) => sin(x)
    sin(x) => foo(x,x)
end
@testset "Basic Equalities 1" begin
    @test (@areequal r foo(b,c) foo(d,d)) == false
end


r = @theory begin
    a * 1 => foo
    a * 2 => bar
    1 * a => baz
    2 * a => mag
end
@testset "Matching Literals" begin
    @test (@areequal r a * 1 foo) == true
    @test (@areequal r a * 2 foo) == false
    @test (@areequal r a * 1 bar) == false
    @test (@areequal r a * 2 bar) == true

    @test (@areequal r 1 * a baz) == true
    @test (@areequal r 2 * a baz) == false
    @test (@areequal r 1 * a mag) == false
    @test (@areequal r 2 * a mag) == true
end


comm_monoid = @theory begin
    a * b => b * a
    a * 1 => a
    a * (b * c) => (a * b) * c
end
@testset "Basic Equalities - Commutative Monoid" begin
    @test true == (@areequal comm_monoid a*(c*(1*d)) c*(1*(d*a)) )
    @test true == (@areequal comm_monoid x*y y*x )
    @test true == (@areequal comm_monoid (x*x)*(x * 1) x*(x*x) )
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
    @test true == (@areequal t (a * b) + (a * c) a*(b+c) )
    @test true == (@areequal t a*(c*(1*d)) c*(1*(d*a)) )
    @test true == (@areequal t a+(b*(c*d)) ((d*c)*b)+a )
    @test true == (@areequal t (x+y)*(a+b) ((a*(x+y)) + b*(x+y)) ((x*(a+b)) + y*(a+b)) )
    @test true == (@areequal t (((x*a + x*b) + y*a) + y*b) (x+y)*(a+b) )
    @test true == (@areequal t a+(b*(c*d)) ((d*c)*b)+a )
    @test true == (@areequal t a+inv(a) 0 (x*y)+inv(x*y) 1*0 )
end

@testset "Basic Equalities - False statements" begin
    @test false == (@areequal t (a * b) + (a * c) a*(b+a))
    @test false == (@areequal t (a * c) + (a * c) a*(b+c) )
    @test false == (@areequal t a*(c*c) c*(1*(d*a)) )
    @test false == (@areequal t c+(b*(c*d)) ((d*c)*b)+a )
    @test false == (@areequal t (x+y)*(a+c) ((a*(x+y)) + b*(x+y)) )
    @test false == (@areequal t ((x*(a+b)) + y*(a+b)) (x+y)*(a+c) )
    @test false == (@areequal t (((x*a + x*b) + y*a) + y*b) (x+y)*(a+x) )
    @test false == (@areequal t a+(b*(c*a)) ((d*c)*b)+a )
    @test false == (@areequal t a+inv(a) a )
    @test false == (@areequal t (x*y)+inv(x*y) 1 )
end

# expr = cleanast(:(1 * 1 * 1 * 1 * 1 * zoo * 1 * 1 * foo * 1))
#
# G = EGraph(expr)
#
# @time saturate!(G, comm_monoid)
#
# G.H |> display
