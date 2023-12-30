using Metatheory
using Metatheory.Rewriters
using Test

apply(f, x) = f(x)
fand(f, g) = x -> f(x) && g(x)

array_theory = @theory x y f g M N begin
  #map(f,x)[n:m] = map(f,x[n:m]) # but does NOT commute with filter
  map(f, fill(x, N)) == fill(apply(f, x), N) # hmm
  # cumsum(fill(x,N))           == collect(x:x:(N*x))
  fill(x, N)[y] --> x
  length(fill(x, N)) --> N
  reverse(reverse(x)) --> x
  sum(fill(x, N)) --> x * N
  map(f, reverse(x)) == reverse(map(f, x))
  filter(f, reverse(x)) == reverse(filter(f, x))
  reverse(fill(x, N)) == fill(x, N)
  filter(f, fill(x, N)) == (
    if apply(f, x)
      fill(x, N)
    else
      fill(x, 0)
    end
  )
  filter(f, filter(g, x)) == filter(fand(f, g), x) # using functional &&
  cat(fill(x, N), fill(x, M)) == fill(x, N + M)
  cat(map(f, x), map(f, y)) == map(f, cat(x, y))
  map(f, cat(x, y)) == cat(map(f, x), map(f, y))
  map(f, map(g, x)) == map(f ∘ g, x)
  reverse(cat(x, y)) == cat(reverse(y), reverse(x))
  map(f, x)[y] == apply(f, x[y])
  apply(f ∘ g, x) == apply(f, apply(g, x))

  reduce(g, map(f, x)) == mapreduce(f, g, x)
  foldl(g, map(f, x)) == mapfoldl(f, g, x)
  foldr(g, map(f, x)) == mapfoldr(f, g, x)
end

asymptot_t = @theory x y z n m f g begin
  (length(filter(f, x)) <= length(x)) => true
  length(cat(x, y)) --> length(x) + length(y)
  length(map(f, x)) --> length(x)
  length(x::UnitRange) => length(x)
end

fold_theory = @theory x y z begin
  x::Number * y::Number => x * y
  x::Number + y::Number => x + y
  x::Number / y::Number => x / y
  x::Number - y::Number => x / y
  # etc...
end

# Simplify expressions like :(d->3:size(A,d)-3) given an explicit value for d
import Base.Cartesian: inlineanonymous


tryinlineanonymous(x) = nothing
function tryinlineanonymous(ex::Expr)
  ex.head != :call && return nothing
  f = operation(ex)
  (!(f isa Expr) || f.head !== :->) && return nothing
  arg = arguments(ex)[1]
  try
    return inlineanonymous(f, arg)
  catch e
    return nothing
  end
end

normalize_theory = @theory x y z f g begin
  fand(f, g)  => :(x -> ($f)(x) && ($g)(x))
  apply(f, x) => Expr(:call, f, x)
end


stream_fusion_cost(n::ENodeLiteral, g::EGraph) = 1
function stream_fusion_cost(n::ENode, g::EGraph)
  cost = 1 + arity(n)
  for id in arguments(n)
    eclass = g[id]
    !hasdata(eclass, stream_fusion_cost) && (cost += Inf; break)
    cost += last(getdata(eclass, stream_fusion_cost))
  end

  operation(n) ∈ (:map, :filter) && (cost += 10)

  return cost
end

function stream_optimize(ex)
  g = EGraph(ex)
  saturate!(g, array_theory)
  ex = extract!(g, stream_fusion_cost) # TODO cost fun with asymptotic complexity
  ex = Fixpoint(Postwalk(Chain([tryinlineanonymous; normalize_theory; fold_theory])))(ex)
  return ex
end


@testset "Stream Fusion" begin
  ex = :(map(x -> 7 * x, fill(3, 4)))
  opt = stream_optimize(ex)
  @test opt == :(fill(21, 4))

  ex = :(map(x -> 7 * x, fill(3, 4))[1])
  opt = stream_optimize(ex)
  @test opt == 21
end

# ['a','1','2','3','4']
ex = :(filter(ispow2, filter(iseven, reverse(reverse(fill(4, 100))))))
@test Base.remove_linenums!(stream_optimize(ex)) ==
      Base.remove_linenums!(:(filter(x -> ispow2(x) && iseven(x), fill(4, 100))))


ex = :(map(x -> 7 * x, reverse(reverse(fill(13, 40)))))
@test stream_optimize(ex) == :(fill(91, 40))

