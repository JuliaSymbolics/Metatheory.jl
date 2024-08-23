"""
A data structure to maintain a queue of unique elements.
Notably, insert/pop operations have O(1) expected amortized runtime complexity.
"""

struct UniqueQueue{T}
  set::Set{T}
  vec::Vector{T}
end


UniqueQueue{T}() where {T} = UniqueQueue{T}(Set{T}(), T[])

function Base.push!(uq::UniqueQueue{T}, x::T) where {T}
  # checks if x is contained in s and adds x if it is not, using a single hash call and lookup
  # available from Julia 1.11
  function in!(x::T, s::Set)
    idx, sh = Base.ht_keyindex2_shorthash!(s.dict, x)
    idx > 0 && return true
    _setindex!(s.dict, nothing, x, -idx, sh)
    
    false
  end

  if !in!(x, uq.set)
    push!(uq.vec, x)
  end
end

function Base.append!(uq::UniqueQueue{T}, xs::Vector{T}) where {T}
  for x in xs
    push!(uq, x)
  end
end

function Base.pop!(uq::UniqueQueue{T}) where {T}
  v = pop!(uq.vec)
  delete!(uq.set, v)
  v
end

Base.isempty(uq::UniqueQueue) = isempty(uq.vec)