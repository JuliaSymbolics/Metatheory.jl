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
  if !(x in uq.set)
    push!(uq.set, x)
    push!(uq.vec, x)
  end
end

function Base.append!(uq::UniqueQueue{T}, xs::Vector{T}) where {T}
  for x in xs
    push!(uq, x)
  end
end

function Base.pop!(uq::UniqueQueue{T}) where {T}
  # TODO maybe popfirst?
  v = pop!(uq.vec)
  delete!(uq.set, v)
  v
end

Base.isempty(uq::UniqueQueue) = isempty(uq.vec)