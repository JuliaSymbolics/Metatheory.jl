using Metatheory
using Test

n = 10

uf = UnionFind()
for _ in 1:n
  push!(uf)
end

union!(uf, UInt(1), UInt(2))
union!(uf, UInt(1), UInt(3))
union!(uf, UInt(1), UInt(4))

union!(uf, UInt(6), UInt(8))
union!(uf, UInt(6), UInt(9))
union!(uf, UInt(6), UInt(10))

for i in 1:n
  find(uf, UInt(i))
end
@test uf.parents == UInt[1, 1, 1, 1, 5, 6, 7, 6, 6, 6]
