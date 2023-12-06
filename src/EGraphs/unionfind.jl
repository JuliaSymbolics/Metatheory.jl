struct UnionFind
  parents::Vector{Int}
end

UnionFind() = UnionFind(Int[])

function Base.push!(uf::UnionFind)
  l = length(uf.parents) + 1
  push!(uf.parents, l)
  l
end

Base.length(uf::UnionFind) = length(uf.parents)

function Base.union!(uf::UnionFind, i::Int, j::Int)
  uf.parents[j] = i
  i
end

function find(uf::UnionFind, i::Int)
  while i != uf.parents[i]
    i = uf.parents[i]
  end
  i
end


function normalize!(uf::UnionFind)
  for i in 1:length(uf)
    p_i = find(uf, i)
    if p_i != i
      uf.parents[i] = p_i
    end
  end
  # x.normalized[] = true
end