using Test
using Metatheory
using Metatheory.Library
using Metatheory.Schedulers
using TermInterface

mult_t = @commutative_monoid (*) 1
plus_t = @commutative_monoid (+) 0

minus_t = @theory a b begin
  # TODO Jacques Carette's post in zulip chat
  a - a --> 0
  a - b --> a + (-1 * b)
  -a --> -1 * a
  a + (-b) --> a + (-1 * b)
end


mulplus_t = @theory a b c begin
  # TODO FIXME these rules improves performance and avoids commutative
  # explosion of the egraph
  a + a --> 2 * a
  0 * a --> 0
  a * 0 --> 0
  a * (b + c) == ((a * b) + (a * c))
  a + (b * a) --> ((b + 1) * a)
end

pow_t = @theory x y z n m p q begin
  (y^n) * y --> y^(n + 1)
  x^n * x^m == x^(n + m)
  (x * y)^z == x^z * y^z
  (x^p)^q == x^(p * q)
  x^0 --> 1
  0^x --> 0
  1^x --> 1
  x^1 --> x
  x * x --> x^2
  inv(x) == x^(-1)
end

div_t = @theory x y z begin
  x / 1 --> x
  # x / x => 1 TODO SIGN ANALYSIS
  x / (x / y) --> y
  x * (y / x) --> y
  x * (y / z) == (x * y) / z
  x^(-1) == 1 / x
end

trig_t = @theory θ begin
  sin(θ)^2 + cos(θ)^2 --> 1
  sin(θ)^2 - 1 --> cos(θ)^2
  cos(θ)^2 - 1 --> sin(θ)^2
  tan(θ)^2 - sec(θ)^2 --> 1
  tan(θ)^2 + 1 --> sec(θ)^2
  sec(θ)^2 - 1 --> tan(θ)^2
  cot(θ)^2 - csc(θ)^2 --> 1
  cot(θ)^2 + 1 --> csc(θ)^2
  csc(θ)^2 - 1 --> cot(θ)^2
end

# Dynamic rules
fold_t = @theory a b begin
  -(a::Number) => -a
  a::Number + b::Number => a + b
  a::Number * b::Number => a * b
  a::Number^b::Number => begin
    b < 0 && a isa Int && (a = float(a))
    a^b
  end
  a::Number / b::Number => a / b
end

using Calculus: differentiate
function ∂ end

diff_t = @theory x y begin
  ∂(y, x::Symbol) => begin
    z = extract!(_egraph, simplcost; root = y.id)
    @show z
    zd = differentiate(z, x)
    @show zd
    zd
  end
end

cas = fold_t ∪ mult_t ∪ plus_t ∪ minus_t ∪ mulplus_t ∪ pow_t ∪ div_t ∪ trig_t ∪ diff_t


function customlt(x, y)
  if typeof(x) == Expr && typeof(y) == Expr
    false
  elseif typeof(x) == typeof(y)
    isless(x, y)
  elseif x isa Symbol && y isa Number
    false
  elseif x isa Expr && y isa Number
    false
  elseif x isa Expr && y isa Symbol
    false
  else
    true
  end
end

canonical_t = @theory x y n xs ys begin
  # restore n-arity
  (x * x) --> x^2
  (x^n::Number * x) --> x^(n + 1)
  (x * x^n::Number) --> x^(n + 1)
  (x + (+)(ys...)) --> +(x, ys...)
  ((+)(xs...) + y) --> +(xs..., y)
  (x * (*)(ys...)) --> *(x, ys...)
  ((*)(xs...) * y) --> *(xs..., y)

  (*)(xs...) => Expr(:call, :*, sort!(xs; lt = customlt)...)
  (+)(xs...) => Expr(:call, :+, sort!(xs; lt = customlt)...)
end


function simplcost(n::ENodeTerm, g::EGraph)
  cost = 0 + arity(n)
  if operation(n) == :∂
    cost += 20
  end
  for id in arguments(n)
    eclass = g[id]
    !hasdata(eclass, simplcost) && (cost += Inf; break)
    cost += last(getdata(eclass, simplcost))
  end
  return cost
end

simplcost(n::ENodeLiteral, g::EGraph) = 0

function simplify(ex; steps = 4)
  params = SaturationParams(
    scheduler = ScoredScheduler,
    eclasslimit = 5000,
    timeout = 7,
    schedulerparams = (1000, 5, Schedulers.exprsize),
    #stopwhen=stopwhen,
  )
  hist = UInt64[]
  push!(hist, hash(ex))
  for i in 1:steps
    g = EGraph(ex)
    @profview_allocs saturate!(g, cas, params)
    ex = extract!(g, simplcost)
    ex = rewrite(ex, canonical_t)
    if !TermInterface.istree(ex)
      return ex
    end
    if hash(ex) ∈ hist
      println("loop detected $ex")
      return ex
    end
    println(ex)
    push!(hist, hash(ex))
  end

end

@test :(4a) == simplify(:(2a + a + a))
@test :(a * b * c) == simplify(:(a * c * b))
@test :(2x) == simplify(:(1 * x * 2))
@test :((a * b)^2) == simplify(:((a * b)^2))
@test :((a * b)^6) == simplify(:((a^2 * b^2)^3))
@test :(a + b + d) == simplify(:(a + b + (0 * c) + d))
@test :(a + b) == simplify(:(a + b + (c * 0) + d - d))
@test :(a) == simplify(:((a + d) - d))
@test :(a + b + d) == simplify(:(a + b * c^0 + d))
@test :(a * b * x^(d + y)) == simplify(:(a * x^y * b * x^d))
@test :(a * b * x^74103) == simplify(:(a * x^(12 + 3) * b * x^(42^3)))

@test 1 == simplify(:((x + y)^(a * 0) / (y + x)^0))
@test 2 == simplify(:(cos(x)^2 + 1 + sin(x)^2))
@test 2 == simplify(:(cos(y)^2 + 1 + sin(y)^2))
@test 2 == simplify(:(sin(y)^2 + cos(y)^2 + 1))

@test :(y + sec(x)^2) == simplify(:(1 + y + tan(x)^2))
@test :(y + csc(x)^2) == simplify(:(1 + y + cot(x)^2))



# simplify(:( ∂(x^2, x)))

@time simplify(:(∂(x^(cos(x)), x)))

@test :(2x^3) == simplify(:(x * ∂(x^2, x) * x))

# @simplify ∂(y^3, y) * ∂(x^2 + 2, x) / y * x

# @simplify (6 * x * x * y)

# @simplify ∂(y^3, y) / y

# # ex = :( ∂(x^(cos(x)), x) )
# ex = :( (6 * x * x * y) )
# g = EGraph(ex)
# saturate!(g, cas)
# g.classes
# extract!(g, simplcost; root=g.root)

# params = SaturationParams(
#     scheduler=BackoffScheduler,
#     eclasslimit=5000,
#     timeout=7,
#     schedulerparams=(1000,5),
#     #stopwhen=stopwhen,
# )

# ex = :((x+y)^(a*0) / (y+x)^0)
# g = EGraph(ex)
# @profview println(saturate!(g, cas, params))

# ex = extract!(g, simplcost)
# ex = rewrite(ex, canonical_t; clean=false)


# FIXME this is a hack to get the test to work.
if VERSION < v"1.9.0-DEV"
  function EGraphs.make(::Val{:type_analysis}, g::EGraph, n::ENodeLiteral)
    v = n.value
    if v == :im
      typeof(im)
    else
      typeof(v)
    end
  end

  function EGraphs.make(::Val{:type_analysis}, g::EGraph, n::ENodeTerm)
    symtype(n) !== Expr && return Any
    if exprhead(n) != :call
      # println("$n is not a call")
      t = Any
      # println("analyzed type of $n is $t")
      return t
    end
    sym = operation(n)
    if !(sym isa Symbol)
      # println("head $sym is not a symbol")
      t = Any
      # println("analyzed type of $n is $t")
      return t
    end

    symval = getfield(@__MODULE__, sym)
    child_classes = map(x -> g[x], arguments(n))
    child_types = Tuple(map(x -> getdata(x, :type_analysis, Any), child_classes))

    # t = t_arr[1]
    t = Core.Compiler.return_type(symval, child_types)

    if t == Union{}
      throw(MethodError(symval, child_types))
    end
    # println("analyzed type of $n is $t")
    return t
  end

  EGraphs.join(::Val{:type_analysis}, from, to) = typejoin(from, to)

  EGraphs.islazy(::Val{:type_analysis}) = true

  function infer(e)
    g = EGraph(e)
    analyze!(g, :type_analysis)
    getdata(g[g.root], :type_analysis)
  end


  ex1 = :(cos(1 + 3.0) + 4 + (4 - 4im))
  ex2 = :("ciao" * 2)
  ex3 = :("ciao" * " mondo")

  @test ComplexF64 == infer(ex1)
  @test_throws MethodError infer(ex2)
  @test String == infer(ex3)
end
