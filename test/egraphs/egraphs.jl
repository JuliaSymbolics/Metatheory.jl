
using Test
using Metatheory

@testset "Merging" begin
  testexpr = :((a * 2) / 2)
  testmatch = :(a << 1)
  g = EGraph(testexpr)
  t2 = addexpr!(g, testmatch)
  union!(g, t2, 3)
  @test find(g, t2) == find(g, 3)
  # DOES NOT UPWARD MERGE
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
  @test find(g, t2) == find(g, t1)
  @test find(g, t2) == find(g, t1)
  rebuild!(g)
  @test find(g, ec1) == find(g, ec2)
end


@testset "Simple nested congruence" begin
  apply(n, f, x) = n == 0 ? x : apply(n - 1, f, f(x))
  f(x) = Expr(:call, :f, x)

  g = EGraph(:a)

  t1 = addexpr!(g, apply(6, f, :a))
  t2 = addexpr!(g, apply(9, f, :a))

  c_id = union!(g, t1, 1) # a == apply(6,f,a)
  c2_id = union!(g, t2, 1) # a == apply(9,f,a)

  rebuild!(g)

  t3 = addexpr!(g, apply(3, f, :a))
  t4 = addexpr!(g, apply(7, f, :a))

  # f^m(a) = a = f^n(a) ⟹ f^(gcd(m,n))(a) = a
  @test find(g, t1) == find(g, 1)
  @test find(g, t2) == find(g, 1)
  @test find(g, t3) == find(g, 1)
  @test find(g, t4) != find(g, 1)

  # if m or n is prime, f(a) = a
  t5 = addexpr!(g, apply(11, f, :a))
  t6 = addexpr!(g, apply(1, f, :a))
  c5_id = union!(g, t5, EClassId(1)) # a == apply(11,f,a)

  rebuild!(g)

  @test find(g, t5) == find(g, 1)
  @test find(g, t6) == find(g, 1)
end
