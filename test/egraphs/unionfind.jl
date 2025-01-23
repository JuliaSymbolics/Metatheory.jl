using Metatheory
using Test

n = 10

uf = UnionFind()
for _ in 1:n
  push!(uf)
end

union!(uf, Id(1), Id(2))
union!(uf, Id(1), Id(3))
union!(uf, Id(1), Id(4))

union!(uf, Id(6), Id(8))
union!(uf, Id(6), Id(9))
union!(uf, Id(6), Id(10))

for i in 1:n
  find(uf, Id(i))
end
@test uf.parents == Id[1, 1, 1, 1, 5, 6, 7, 6, 6, 6]
