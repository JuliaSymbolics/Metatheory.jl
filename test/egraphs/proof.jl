using Metatheory, Test

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
find_flat_proof(g.proof, id_a, id_b)



id_d = addexpr!(g, :d)

union!(g, id_a, id_d, 3)
print_proof(g)

# Takes 4 steps
@test length(find_flat_proof(g.proof, id_a, id_d)) == 4


id_e = addexpr!(g, :e)
@test isempty(find_flat_proof(g.proof, id_a, id_e))