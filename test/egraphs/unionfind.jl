using Metatheory
using Test

n = 10

uf = UnionFind()
for _ in 1:n
  push!(uf)
end

union!(uf, 1, 2)
union!(uf, 1, 3)
union!(uf, 1, 4)

union!(uf, 6, 8)
union!(uf, 6, 9)
union!(uf, 6, 10)

for i in 1:n
  find(uf, i)
end
@test uf.parents == [1, 1, 1, 1, 5, 6, 7, 6, 6, 6]

# TODO test path compression