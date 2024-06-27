using Metatheory

g = EGraph(; proof = true)

id_a = addexpr!(g, :a)

print_proof(g)

id_b = addexpr!(g, :b)


union!(g, id_a, id_b, 1)

print_proof(g)