struct UnionFind
  parents::Vector{UInt}
end

UnionFind() = UnionFind(UInt[])

function Base.push!(uf::UnionFind)::UInt
  l = length(uf.parents) + 1
  push!(uf.parents, l)
  l
end

Base.length(uf::UnionFind) = length(uf.parents)

function Base.union!(uf::UnionFind, i::UInt, j::UInt)
  uf.parents[j] = i
  i
end

function find(uf::UnionFind, i::UInt)
  while i != uf.parents[i]
    i = uf.parents[i]
  end
  i
end
