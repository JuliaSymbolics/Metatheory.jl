
"Optimized, unsafe, infinite-growing buffer backed by Memory{T} (requires Julia ≥ 1.11)."
mutable struct OptBuffer{T<:Unsigned}
  mem::Memory{T}
  i::Int
  cap::Int
  growth::Float64
end

function OptBuffer{T}(cap::Int, growth = 0.4) where {T<:Unsigned}
  # cap=0 is valid; a 0-capacity buffer must not be pushed to.
  mem = Memory{T}(undef, cap)
  OptBuffer{T}(mem, 0, cap, growth)
end

Base.@inline function Base.push!(b::OptBuffer{T}, el::T) where {T}
  b.i += 1
  if b.i > b.cap
    new_cap = b.cap + ceil(Int, b.cap * b.growth) + 1
    new_mem = Memory{T}(undef, new_cap)
    unsafe_copyto!(new_mem, 1, b.mem, 1, b.cap)
    b.mem = new_mem
    b.cap = new_cap
  end
  @inbounds b.mem[b.i] = el
  b
end

Base.@inline function Base.pop!(b::OptBuffer{T})::T where {T}
  # UNSAFE: assumes b.i > 0
  val = @inbounds b.mem[b.i]
  b.i -= 1
  val
end

"""
Bulk-append `src[from:to]` into `b` via a single `unsafe_copyto!` call.
Avoids per-element push overhead for segment child copies.
"""
@inline function push_many!(b::OptBuffer{T}, src::Memory{T}, from::Int, to::Int) where {T}
  count = to - from + 1
  count <= 0 && return b
  new_i = b.i + count
  while new_i > b.cap
    new_cap = b.cap + ceil(Int, b.cap * b.growth) + 1
    new_mem = Memory{T}(undef, new_cap)
    unsafe_copyto!(new_mem, 1, b.mem, 1, b.i)
    b.mem = new_mem
    b.cap = new_cap
  end
  unsafe_copyto!(b.mem, b.i + 1, src, from, count)
  b.i = new_i
  b
end

@inline Base.getindex(b::OptBuffer{T}, idx) where {T} = @inbounds b.mem[idx]
@inline Base.view(b::OptBuffer{T}, idx) where {T} = view(b.mem, idx)
Base.isempty(b::OptBuffer{T}) where {T} = b.i === 0
Base.empty!(b::OptBuffer{T}) where {T} = (b.i = 0)
@inline Base.length(b::OptBuffer{T}) where {T} = b.i
Base.iterate(b::OptBuffer{T}, i = 1) where {T} = i <= b.i ? (@inbounds b.mem[i], i + 1) : nothing
