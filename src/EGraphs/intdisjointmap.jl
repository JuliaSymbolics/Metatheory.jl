struct IntDisjointSet{T<:Integer}
  parents::Vector{T}
  normalized::Ref{Bool}
end

IntDisjointSet{T}() where {T<:Integer} = IntDisjointSet{T}(Vector{T}[], Ref(true))
Base.length(x::IntDisjointSet) = length(x.parents)

function Base.push!(x::IntDisjointSet{T}) where {T}
  push!(x.parents, convert(T, -1))
  convert(T, length(x))
end

function find_root(x::IntDisjointSet{T}, i::T) where {T}
  while x.parents[i] >= 0
    i = x.parents[i]
  end
  return convert(T, i)
end

function in_same_set(x::IntDisjointSet{T}, a::T, b::T) where {T}
  find_root(x, a) == find_root(x, b)
end

function Base.union!(x::IntDisjointSet{T}, i::T, j::T) where {T}
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
  return convert(T, pj)
end

function normalize!(x::IntDisjointSet{T}) where {T}
  for i in convert(T, length(x))
    pi = find_root(x, i)
    if pi != i
      x.parents[i] = convert(T, pi)
    end
  end
  x.normalized[] = true
end

# If normalized we don't even need a loop here.
function _find_root_normal(x::IntDisjointSet{T}, i::T) where {T}
  pi = x.parents[i]
  if pi < 0 # Is `i` a root?
    return i
  else
    return pi
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
