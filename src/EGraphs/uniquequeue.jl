"""
A data structure to maintain a queue of unique elements.
Notably, insert/pop operations have O(1) expected amortized runtime complexity.

Note: this is really more of a stack than a queue, because it is LIFO (last in
first out) rather than FIFO (first in, last out). That is,

```julia
q = UniqueQueue{Int}()
push!(q, 1)
push!(q, 2)
assert(pop!(q) == 2)
assert(pop!(q) == 1)
```

The "twist" that makes this a unique queue is that it "ignores" pushes of
elements that already exist on the queue.

This is useful behavior for managing a queue of "dirty" elements to clean up;
if something is marked dirty twice, we only have to clean it once.

The set is used to quickly lookup if an element is in the queue, the vector is
used to maintain the ordering of elements in the queue.
"""
struct UniqueQueue{T}
  set::Set{T}
  vec::Vector{T}
end


UniqueQueue{T}() where {T} = UniqueQueue{T}(Set{T}(), T[])

"""
    Base.push!(uq::UniqueQueue{T}, x::T) where {T}

This adds `x` to the top of the queue *only if* it does not already exist
somewhere in the queue.
"""
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
  v = pop!(uq.vec)
  delete!(uq.set, v)
  v
end

Base.isempty(uq::UniqueQueue) = isempty(uq.vec)
