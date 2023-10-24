# function Base.union!(x::IntDisjointSet, i::Int, j::Int)
#   pi = find_root(x, i)
#   pj = find_root(x, j)
#   if pi != pj
#     x.normalized[] = false
#     isize = -x.parents[pi]
#     jsize = -x.parents[pj]
#     if isize > jsize # swap to make size of i less than j
#       pi, pj = pj, pi
#       isize, jsize = jsize, isize
#     end
#     x.parents[pj] -= isize # increase new size of pj
#     x.parents[pi] = pj # set parent of pi to pj
#   end
#   return pj
# end

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