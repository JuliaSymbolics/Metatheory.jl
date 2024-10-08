
"Optimized, unsafe, infinite-growing byte buffer implementation"
mutable struct OptBuffer{T<:Unsigned}
  v::Vector{T}
  i::Int
  cap::Int
  growth::Float64
end

function OptBuffer{T}(cap::Int, growth = 0.4) where {T<:Unsigned}
  v = Vector{T}(undef, cap)
  OptBuffer{T}(v, 0, cap, growth)
end

Base.@inline function Base.push!(b::OptBuffer{T}, el::T) where {T}
  b.i += 1
  if b.i === b.cap
    delta = ceil(Int, b.cap * b.growth) + 1
    Base._growend!(b.v, delta)
    b.cap += delta
  end
  @inbounds b.v[b.i] = el
  b
end

Base.@inline function Base.pop!(b::OptBuffer{T})::T where {T}
  # THIS IS UNSAFE! ASSUMES ALWAYS THAT b.i is > 1
  val = @inbounds b.v[b.i]
  b.i -= 1
  val
end

Base.resize!(b::OptBuffer{T}, n::Int) where {T} = b.i = n
Base.isempty(b::OptBuffer{T}) where {T} = b.i === 0
Base.empty!(b::OptBuffer{T}) where {T} = (b.i = 0)
@inline Base.length(b::OptBuffer{T}) where {T} = b.i
Base.iterate(b::OptBuffer{T}, i=1) where {T} = iterate(b.v[1:b.i], i)