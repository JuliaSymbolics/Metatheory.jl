using Metatheory, Test
using Metatheory.Library
import JSON

g = EGraph(; proof = true)

id_a = addexpr!(g, :a)
println(find_flat_proof(g.proof, id_a, id_a))
@test length(find_flat_proof(g.proof, id_a, id_a)) == 1

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
find_flat_proof(g.proof, id_a, id_b)



id_d = addexpr!(g, :d)

union!(g, id_a, id_d, 3)
print_proof(g)
println(find_flat_proof(g.proof, id_c, id_d))
# Takes 4 steps
@test length(find_flat_proof(g.proof, id_c, id_d)) == 3

# TODO: Why doesn't d have a its leader
for id in [id_a, id_b, id_c, id_d]
  leader = rewrite_to_leader(g.proof, id)
  @test leader.leader == id_d
  @test length(leader.proof) == length(find_flat_proof(g.proof, id, id_a))
end



id_e = addexpr!(g, :e)
@test isempty(find_flat_proof(g.proof, id_a, id_e))

id_z = addexpr!(g, :z)

comm_monoid = @commutative_monoid (*) 1

fold_mul = @theory begin
  ~a::Number * ~b::Number => ~a * ~b
end

ex = :(a * b * 4 * z)
id_ex = addexpr!(g, ex)
ex_to = :(d * c * 4 * z)
id_ex_to = addexpr!(g, ex_to)
print_nodes(g)

println(pretty_dict(g))
prf = find_node_proof(g, id_ex, id_ex_to)
if prf === nothing
  println("No proof")
else
  println(JSON.json(detailed_dict(prf[1], g)))
  println(JSON.json(detailed_dict(prf[2], g)))
end
