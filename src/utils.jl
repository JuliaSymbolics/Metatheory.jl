using Base: ImmutableDict
using TimerOutputs

const binarize_ops = [:(+), :(*), (+), (*)]

function cleanast(e::Expr)
  # TODO better line removal 
  if e.head === :block
    return Expr(e.head, filter(x -> !(x isa LineNumberNode), e.args)...)
  end

  # Binarize
  if iscall(e)
    op = e.args[1]
    if op ∈ binarize_ops && length(e.args) > 3
      return foldl((x, y) -> Expr(:call, op, x, y), @view e.args[2:end])
    end
  end
  return e
end

const being_timed = Ref{Bool}(false)

macro timer(name, expr)
  :(
    if being_timed[]
      @timeit $(esc(name)) $(esc(expr))
    else
      $(esc(expr))
    end
  )
end

"Useful for debugging: prints the content of the e-graph match buffer in readable format."
function buffer_readable(g, limit, ematch_buffer)
  k = length(ematch_buffer)

  while k > limit
    delimiter = ematch_buffer.v[k]
    @assert delimiter == 0xffffffffffffffffffffffffffffffff
    n = k - 1

    next_delimiter_idx = 0
    n_elems = 0
    for i in n:-1:1
      n_elems += 1
      if ematch_buffer.v[i] == 0xffffffffffffffffffffffffffffffff
        n_elems -= 1
        next_delimiter_idx = i
        break
      end
    end

    match_info = ematch_buffer.v[next_delimiter_idx + 1]
    id = v_pair_first(match_info)
    rule_idx = reinterpret(Int, v_pair_last(match_info))
    rule_idx = abs(rule_idx)

    bindings = @view ematch_buffer.v[(next_delimiter_idx + 2):n]

    print("$id E-Classes: ", map(x -> reinterpret(Int, v_pair_first(x)), bindings))
    print(" Nodes: ", map(x -> reinterpret(Int, v_pair_last(x)), bindings), "\n")

    k = next_delimiter_idx
  end
end


# used for eclasses instead of a dictionary
struct SparseVector{V}
  data::Vector{Union{Nothing,V}}
  nzidx::Vector{Int64} # for iteration over elements
end

SparseVector{V}() where {V} = SparseVector(Vector{Union{Nothing,V}}(), Vector{Int64}()) 

function Base.getindex(v::SparseVector{V}, i) where {V}
  i > 0 || i <= length(v.data) || return nothing
  @inbounds v.data[i]
end

function Base.setindex!(v::SparseVector{V}, val::V, i) where {V}
  i > 0 || throw(KeyError())

  if i > length(v.data)
    m = length(v.data)
    resize!(v.data, ceil(Int64, i*1.4))
    fill!(view(v.data, m+1:length(v.data)), nothing)
    push!(v.nzidx, i)
    @inbounds v.data[i] = val
  elseif !isnothing(v.data[i])
    # overwrite existing value
    @inbounds v.data[i] = val
  else
    push!(v.nzidx, i)
    @inbounds v.data[i] = val
  end
end

function Base.pop!(v::SparseVector, i)
  (i > 0 && i <= length(v.data)) || throw(KeyError()) 

  @inbounds val = v.data[i]
  !isnothing(val) || return val
  deleteat!(v.nzidx, findfirst((==)(i), v.nzidx)) # TODO: a sorted collection could be useful here  
  @inbounds v.data[i] = nothing
  val
end

function Base.deleteat!(v::SparseVector, i)
  (i > 0 && i <= length(v.data)) || return

  !isnothing(v.data[i]) || return
  
  deleteat!(v.nzidx, findfirst((==)(i), v.nzidx)) # TODO: a sorted collection could be useful here
  @inbounds v.data[i] = nothing
  nothing
end

@inline Base.eachindex(v::SparseVector) = v.nzidx
@inline Base.length(v::SparseVector) = length(v.nzidx)
Base.iterate(v::SparseVector, i=1) = i <= length(v.nzidx) ? ((v.nzidx[i], v.data[v.nzidx[i]]), i + 1) : nothing
