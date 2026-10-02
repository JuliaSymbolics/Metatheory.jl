
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

# Constructed collision: portable across Julia hash algorithm changes (#287).
struct Coll
  x::Int
end
Base.hash(::Coll, h::UInt) = hash(0x2870, h)

@testset "Hash-colliding constants stay distinct (#287)" begin
  a, b = Coll(1), Coll(2)
  @test !isequal(a, b)
  @test hash(a) == hash(b)
  @test ENodeLiteral(a) != ENodeLiteral(b)
  g = EGraph(:(f($a, $b)))
  @test g.numclasses == 3
end

# Discourse UInt64-vector pair: only under Julia ≤ 1.12's hash(::AbstractArray).
# https://discourse.julialang.org/t/hash-collision-with-small-vectors/131702
@testset "Discourse vector collision (#287)" begin
  a = [0x0000000000000080, 0x0000000000100000, 0x0000000000000400, 0x0000000000000100]
  b = [0x0000000000000100, 0x0000000000100000, 0x0000000000000080, 0x0000000000000400]
  if hash(a) == hash(b)
    @test !isequal(a, b)
    @test ENodeLiteral(a) != ENodeLiteral(b)
    g = EGraph(:($a - $b))
    @test g.numclasses == 3
    @test !in_same_set(g.uf, addexpr!(g, a), addexpr!(g, b))
  end
end
