using Metatheory, Test

@testset begin
  "Basic proofs by hand"
  g = EGraph(; proof = true)

  id_a = addexpr!(g, :a)

  # print_proof(g)

  id_b = addexpr!(g, :b)

  union!(g, id_a, id_b, 1)

  print_proof(g)

  proof = find_flat_proof(g.proof, id_a, id_b)
  @test length(proof) == 1

  proof = find_flat_proof(g.proof, id_b, id_a)
  @test length(proof) == 1


  id_c = addexpr!(g, :c)
  union!(g, id_b, id_c, 2)

  print_proof(g)
  proof = find_flat_proof(g.proof, id_a, id_b)
  @test length(proof) == 2

  id_d = addexpr!(g, :d)

  union!(g, id_a, id_d, 3)
  print_proof(g)

  proof = find_flat_proof(g.proof, id_a, id_d)
  @test length(proof) == 1


  proof = find_flat_proof(g.proof, id_c, id_d)
  @test length(proof) == 3

  id_e = addexpr!(g, :e)
  @test isempty(find_flat_proof(g.proof, id_a, id_e))
end

@testset "Basic rewriting proofs" begin
  r = @rule f(~x) --> g(~x)
  g = EGraph(; proof = true)
  id_a = addexpr!(g, :a)
  id_fa = addexpr!(g, :(f(a)))
  id_ga = addexpr!(g, :(g(a)))

  saturate!(g, RewriteRule[r])

  g

  print_proof(g)
  proof = find_flat_proof(g.proof, id_fa, id_ga)
  @test length(proof) == 1

  # =====================

  r = @rule :x == :y
  g = EGraph(; proof = true)
  id_x = addexpr!(g, :x)
  id_y = addexpr!(g, :y)
  id_fx = addexpr!(g, :(f(x)))
  id_fy = addexpr!(g, :(f(y)))

  saturate!(g, RewriteRule[r])

  g

  print_proof(g)
  proof = find_flat_proof(g.proof, id_fx, id_fy)
  @test length(proof) == 1
  @test only(proof).parent_connection.justification === 0  # by congruence
end