struct UnionFind
  parents::Vector{Id}
end

UnionFind() = UnionFind(Id[])

function Base.push!(uf::UnionFind)::Id
  l = length(uf.parents) + 1
  push!(uf.parents, l)
  l
end

Base.length(uf::UnionFind) = length(uf.parents)

function Base.union!(uf::UnionFind, i::Id, j::Id)
  uf.parents[j] = i
  i
end

function find(uf::UnionFind, i::Id)
  # path splitting
  while i != uf.parents[i]
    (i, uf.parents[i]) = (uf.parents[i], uf.parents[uf.parents[i]])
  end

  i
end
