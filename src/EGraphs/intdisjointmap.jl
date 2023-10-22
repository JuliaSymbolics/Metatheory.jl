struct IntDisjointSet
  parents::Vector{Int}
  normalized::Ref{Bool}
end

IntDisjointSet() = IntDisjointSet(Int[], Ref(true))
Base.length(x::IntDisjointSet) = length(x.parents)

function Base.push!(x::IntDisjointSet)::Int
  push!(x.parents, -1)
  length(x)
end

function find_root(x::IntDisjointSet, i::Int)::Int
  while x.parents[i] >= 0
    i = x.parents[i]
  end
  return i
end

function in_same_set(x::IntDisjointSet, a::Int, b::Int)
  find_root(x, a) == find_root(x, b)
end

function Base.union!(x::IntDisjointSet, i::Int, j::Int)
  pi = find_root(x, i)
  pj = find_root(x, j)
  if pi != pj
    x.normalized[] = false
    isize = -x.parents[pi]
    jsize = -x.parents[pj]
    if isize > jsize # swap to make size of i less than j
      pi, pj = pj, pi
      isize, jsize = jsize, isize
    end
    x.parents[pj] -= isize # increase new size of pj
    x.parents[pi] = pj # set parent of pi to pj
  end
  return pj
end

function normalize!(x::IntDisjointSet)
  for i in 1:length(x)
    p_i = find_root(x, i)
    if p_i != i
      x.parents[i] = p_i
    end
  end
  x.normalized[] = true
end

# If normalized we don't even need a loop here.
function _find_root_normal(x::IntDisjointSet, i::Int)
  p_i = x.parents[i]
  if p_i < 0 # Is `i` a root?
    return i
  else
    return p_i
  end
  # return pi
end

function _in_same_set_normal(x::IntDisjointSet, a::Int64, b::Int64)
  _find_root_normal(x, a) == _find_root_normal(x, b)
end

function find_root_if_normal(x::IntDisjointSet, i::Int64)
  if x.normalized[]
    _find_root_normal(x, i)
  else
    find_root(x, i)
  end
end

struct UnionFind
  parents::Vector{Int}
end

function Base.push!(uf::UnionFind)
  l = length(uf.parents)
  push!(uf.parents, l)
  l
end

Base.length(uf::UnionFind) = length(uf.parents)

function Base.union!(uf::IntDisjointSet, i::Int, j::Int)
  uf.parents[j] = i
  i
end

function find(uf::UnionFind, i::Int)
  current = i
  while current != uf.parents[current]
    current = uf.parents[current]
  end
  current
end