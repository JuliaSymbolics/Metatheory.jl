
using Test, Metatheory

@testset "Merging" begin
  testexpr = :((a * 2) / 2)
  testmatch = :(a << 1)
  g = EGraph()
  testexpr_id = addexpr!(g, testexpr)
  t1 = addexpr!(g, :(a * 2)) # get eclass id of a * 2
  t1_node = copy(g[t1].nodes[1])
  
  t2 = addexpr!(g, testmatch)
  t2_node = copy(g[t2].nodes[1])
  union!(g, t2, t1)

  @testset "Behaviour" begin
    @test find(g, t2) == find(g, t1)
  end

  @testset "Internals" begin
    @test length(g[t1].nodes) == 2 # a << 1, a * 2
    @test g[t1].parents == [g[testexpr_id].nodes[1] => testexpr_id]

    # the parents of child eclasses are only touched when we need them (upwards repair only)
    # id_1 = addexpr!(g, 1) # get id of constant 1
    # @test g[id_1].parents == [t1_node => find(g, t1)] # just eclass [a << 1, a * 2]
    # id_a = addexpr!(g, :a)
    # @test g[id_a].parents == [t2_node => find(g, t1)] # just eclass [a << 1, a * 2]
  end
end

# testexpr = :(42a + b * (foo($(Dict(:x => 2)), 42)))

@testset "Simple congruence - rebuilding" begin
  g = EGraph()
  ec1 = addexpr!(g, :(f(a, b)))
  ec2 = addexpr!(g, :(f(a, c)))

  testexpr = :(f(a, b) + f(a, c))

  testec = addexpr!(g, testexpr)

  t1 = addexpr!(g, :b)
  t2 = addexpr!(g, :c)

  union!(g, t2, t1)
  @testset "Behaviour" begin
    @test find(g, t2) == find(g, t1)
    rebuild!(g)
    @test find(g, ec1) == find(g, ec2)
    @test length(g[ec2].nodes) == 1
  end

  @testset "Internals" begin
    aid = addexpr!(g, :a) # get id of :a
    @assert length(g[ec2].nodes) == 1
    # @test g[aid].parents == [g[ec1].nodes[1] => find(g, ec1)]
    # @test g[t1].parents == [g[ec1].nodes[1] => find(g, ec1)]
    @test length(g[testec].nodes) == 1
    @test g[ec1].parents == [g[testec].nodes[1] => find(g, testec)]
  end
end


@testset "Simple nested congruence" begin
  apply(n, f, x) = n == 0 ? x : apply(n - 1, f, f(x))
  f(x) = Expr(:call, :f, x)

  g = EGraph{Expr}(:a)

  a = addexpr!(g, :a)

  t1 = addexpr!(g, apply(6, f, :a))
  t2 = addexpr!(g, apply(9, f, :a))

  union!(g, t1, a) # a == apply(6,f,a)
  union!(g, t2, a) # a == apply(9,f,a)

  rebuild!(g)

  t3 = addexpr!(g, apply(3, f, :a))
  t4 = addexpr!(g, apply(7, f, :a))

  t6_node = 0
  t5 = 0
  @testset "Behaviour" begin
    # f^m(a) = a = f^n(a) ⟹ f^(gcd(m,n))(a) = a
    @test find(g, t1) == find(g, a)
    @test find(g, t2) == find(g, a)
    @test find(g, t3) == find(g, a)
    @test find(g, t4) != find(g, a)

    # if m or n is prime, f(a) = a
    t5 = addexpr!(g, apply(11, f, :a))
    t6 = addexpr!(g, apply(1, f, :a))
    t6_node = g[t6].nodes[1]
    union!(g, t5, a) # a == apply(11,f,a)

    rebuild!(g)

    @test find(g, t5) == find(g, a)
    @test find(g, t6) == find(g, a)
  end

  @testset "Internals" begin
    @test length(g.classes) == 1 # only a single class %id [:a, f(%id)] remains
    @test length(g[a].parents) == 1 # there can be only a single parent
  end
end
