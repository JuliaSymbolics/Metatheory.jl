
# ENV["JULIA_DEBUG"] = Metatheory
using Metatheory
using Metatheory.EGraphs
using Metatheory.EGraphs: in_same_set, find_root

@testset "Merging" begin
  testexpr = :((a * 2) / 2)
  testmatch = :(a << 1)
  G = EGraph(testexpr)
  t2 = addexpr!(G, testmatch)
  merge!(G, t2, EClassId(3))
  @test in_same_set(G.uf, t2, EClassId(3)) == true
  # DOES NOT UPWARD MERGE
end

# testexpr = :(42a + b * (foo($(Dict(:x => 2)), 42)))

@testset "Simple congruence - rebuilding" begin
  G = EGraph()
  ec1 = addexpr!(G, :(f(a, b)))
  ec2 = addexpr!(G, :(f(a, c)))

  testexpr = :(f(a, b) + f(a, c))

  testec = addexpr!(G, testexpr)

  t1 = addexpr!(G, :b)
  t2 = addexpr!(G, :c)

  c_id = merge!(G, t2, t1)
  @test in_same_set(G.uf, c_id, t1)
  @test in_same_set(G.uf, t2, t1)
  rebuild!(G)
  @test in_same_set(G.uf, ec1, ec2)
end


@testset "Simple nested congruence" begin
  apply(n, f, x) = n == 0 ? x : apply(n - 1, f, f(x))
  f(x) = Expr(:call, :f, x)

  G = EGraph(:a)

  t1 = addexpr!(G, apply(6, f, :a))
  t2 = addexpr!(G, apply(9, f, :a))

  c_id = merge!(G, t1, EClassId(1)) # a == apply(6,f,a)
  c2_id = merge!(G, t2, EClassId(1)) # a == apply(9,f,a)


  rebuild!(G)


  t3 = addexpr!(G, apply(3, f, :a))
  t4 = addexpr!(G, apply(7, f, :a))

  # f^m(a) = a = f^n(a) ⟹ f^(gcd(m,n))(a) = a
  @test in_same_set(G.uf, t1, EClassId(1)) == true
  @test in_same_set(G.uf, t2, EClassId(1)) == true
  @test in_same_set(G.uf, t3, EClassId(1)) == true
  @test in_same_set(G.uf, t4, EClassId(1)) == false

  # if m or n is prime, f(a) = a
  t5 = addexpr!(G, apply(11, f, :a))
  t6 = addexpr!(G, apply(1, f, :a))
  c5_id = merge!(G, t5, EClassId(1)) # a == apply(11,f,a)

  rebuild!(G)

  @test in_same_set(G.uf, t5, EClassId(1)) == true
  @test in_same_set(G.uf, t6, EClassId(1)) == true
end

# Julia `isequal`/`hash` alias `false` with `0` and `1.0` with `1`.
# Literals of different types must still get distinct e-classes (#271).
@testset "Type-strict literal hashcons" begin
  @test ENodeLiteral(false) != ENodeLiteral(0)
  @test hash(ENodeLiteral(false)) != hash(ENodeLiteral(0))
  @test ENodeLiteral(1.0) != ENodeLiteral(1)
  @test hash(ENodeLiteral(1.0)) != hash(ENodeLiteral(1))
  @test ENodeLiteral(0) == ENodeLiteral(0)
  @test hash(ENodeLiteral(0)) == hash(ENodeLiteral(0))

  t = @theory begin
    false --> 0 ≥ 1
  end
  g = EGraph(:(false))
  saturate!(g, t)
  id_false = addexpr!(g, false)
  id_zero = addexpr!(g, 0)
  id_one = addexpr!(g, 1)
  @test !in_same_set(g.uf, id_false, id_zero)
  @test !in_same_set(g.uf, id_false, id_one)
  @test !in_same_set(g.uf, id_zero, id_one)

  g2 = EGraph(:(f(false, 0)))
  id_f = addexpr!(g2, false)
  id_z = addexpr!(g2, 0)
  @test find_root(g2.uf, id_f) != find_root(g2.uf, id_z)
  f_nodes = [n for n in g2.classes[find_root(g2.uf, addexpr!(g2, :(f(false, 0))))].nodes if n isa ENodeTerm]
  @test length(f_nodes) == 1
  @test f_nodes[1].args[1] != f_nodes[1].args[2]

  g3 = EGraph(:(f(1.0, 1)))
  id_float = addexpr!(g3, 1.0)
  id_int = addexpr!(g3, 1)
  @test find_root(g3.uf, id_float) != find_root(g3.uf, id_int)
  f3_nodes = [n for n in g3.classes[find_root(g3.uf, addexpr!(g3, :(f(1.0, 1))))].nodes if n isa ENodeTerm]
  @test length(f3_nodes) == 1
  @test f3_nodes[1].args[1] != f3_nodes[1].args[2]
end
