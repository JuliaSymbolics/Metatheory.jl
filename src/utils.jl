using Base: ImmutableDict

const binarize_ops = [:(+), :(*), (+), (*)]

function cleanast(e::Expr)
  # TODO better line removal 
  if isexpr(e, :block)
    return Expr(e.head, filter(x -> !(x isa LineNumberNode), e.args)...)
  end

  # Binarize
  if isexpr(e, :call)
    op = e.args[1]
    if op ∈ binarize_ops && length(e.args) > 3
      return foldl((x, y) -> Expr(:call, op, x, y), @view e.args[2:end])
    end
  end
  return e
end

# Linked List interface
@inline assoc(d::ImmutableDict, k, v) = ImmutableDict(d, k => v)

struct LL{V}
  v::V
  i::Int
end

islist(x) = istree(x) || !isempty(x)

Base.empty(l::LL) = empty(l.v)
Base.isempty(l::LL) = l.i > length(l.v)

Base.length(l::LL) = length(l.v) - l.i + 1
@inline car(l::LL) = l.v[l.i]
@inline cdr(l::LL) = isempty(l) ? empty(l) : LL(l.v, l.i + 1)

# Base.length(t::Term) = length(arguments(t)) + 1 # PIRACY
# Base.isempty(t::Term) = false
# @inline car(t::Term) = operation(t)
# @inline cdr(t::Term) = arguments(t)

@inline car(v) = istree(v) ? head(v) : first(v)
@inline function cdr(v)
  if istree(v)
    children(v)
  else
    islist(v) ? LL(v, 2) : error("asked cdr of empty")
  end
end

@inline take_n(ll::LL, n) = isempty(ll) || n == 0 ? empty(ll) : @views ll.v[(ll.i):(n + ll.i - 1)] # @views handles Tuple
@inline take_n(ll, n) = @views ll[1:n]

@inline function drop_n(ll, n)
  if n === 0
    return ll
  else
    istree(ll) ? drop_n(children(ll), n - 1) : drop_n(cdr(ll), n - 1)
  end
end
@inline drop_n(ll::Union{Tuple,AbstractArray}, n) = drop_n(LL(ll, 1), n)
@inline drop_n(ll::LL, n) = LL(ll.v, ll.i + n)

using TimerOutputs

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
