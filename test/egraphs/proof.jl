using Metatheory

g = EGraph(; proof = true)

id_a = addexpr!(g, :a)

print_proof(g)

id_b = addexpr!(g, :b)

union!(g, id_a, id_b, 1)

print_proof(g)


# a == b, then b == c  show me why a == c 

id_c = addexpr!(g, :c)

union!(g, id_b, id_c, 2)


# a == b, then b == c  show me why b == a 

