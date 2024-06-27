using Metatheory, TermInterface, Test
using Metatheory.Library
using Metatheory.Schedulers

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
  a::Number - b::Number => a - b
  a::Number * b::Number => a * b
  a::Number^b::Number => begin
    b < 0 && a isa Int && (a = float(a))
    a^b
  end
  a::Number / b::Number => a / b
end

diff_t_onearg = @theory x begin
  diff(sqrt(x), x) --> 1 / 2 / sqrt(x)
  diff(cbrt(x), x) --> 1 / 3 / cbrt(x)^2
  diff(log(x), x) --> 1 / x
  diff(exp(x), x) --> exp(x)
  diff(sin(x), x) --> cos(x)
  diff(cos(x), x) --> -sin(x)
  diff(tan(x), x) --> (1 + tan(x)^2)
  diff(sec(x), x) --> sec(x) * tan(x)
  diff(csc(x), x) --> -csc(x) * cot(x)
  diff(cot(x), x) --> -(1 + cot(x)^2)
end

diff_t_base = @theory x y n begin
  diff(x, x) --> 1
  diff(n::Number, x) --> 0
  diff(y^1, x) --> 1
  diff(y^(n::Number), x) --> n * y^(n - 1)
end

diff_t_composite = @theory x a b c begin
  diff(a + b, x) == diff(a, x) + diff(b, x)
  diff(a * b, x) == diff(a, x) * b + a * diff(b, x) # product rule 
  # if diff(b,x) == 0 
  #         return :( $y * $xp * ($x ^ ($y - 1)) )

  diff(a^b, x) == a^b * (diff(b, x) * log(a) + b * (diff(a, x) / a))
end

diff_t = diff_t_base ∪ diff_t_onearg ∪ diff_t_composite

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


function simplcost(n::VecExpr, op, costs)
  v_isexpr(n) || return 1
  # @show op
  # @show(sum(costs))
  1 + sum(costs) + (op in (:∂, diff, :diff) ? 200 : 0)
end

function simplify(ex; steps = 4)
  params = SaturationParams(
  # scheduler = ScoredScheduler,
  # eclasslimit = 5000,
  # timeout = 7,
  # schedulerparams = (match_limit = 1000, ban_length = 5),
  #stopwhen=stopwhen,
  )
  hist = UInt64[]
  push!(hist, hash(ex))
  for i in 1:steps
    g = EGraph(ex)
    saturate!(g, cas, params)
    ex = extract!(g, simplcost)
    ex = rewrite(ex, canonical_t)
    if !isexpr(ex) || hash(ex) ∈ hist
      return ex
    end
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

@test_broken simplify(:(diff(x^2, x))) == :(2x)

@test_broken simplify(:(diff(x^(cos(x)), x))) == :((cos(x) / x + -(sin(x)) * log(x)) * x^cos(x))

@test_broken simplify(:(x * diff(x^2, x) * x)) == :(2x)

# @test_broken simplify(:(diff(y^3, y) * diff(x^2 + 2, x) / y * x)) == :(3y^2)

@test simplify(:(6 * x * x * y)) == :(6 * y * x^2)

@test_broken simplify(:(diff(y^3, y) / y)) == :(3y^2)


# params = SaturationParams(
#     scheduler=BackoffScheduler,
#     eclasslimit=5000,
#     timeout=7,
#     (match_limit = 1000, ban_length = 5),
#     #stopwhen=stopwhen,
# )

# ex = :((x+y)^(a*0) / (y+x)^0)
# g = EGraph(ex)
# @profview println(saturate!(g, cas, params))

# ex = extract!(g, simplcost)
# ex = rewrite(ex, canonical_t; clean=false)


function EGraphs.make(g::EGraph{Expr,Type}, n::VecExpr)
  h = get_constant(g, v_head(n))
  v_isexpr(n) || return (h in (:im, im) ? Complex : typeof(h))
  v_iscall(n) || return (Any)

  op = (h isa Symbol) ? getfield(@__MODULE__, h) : op
  child_types = map(id -> g[id].data, v_children(n))
  return Base.promote_op(op, child_types...)
end


EGraphs.join(from::Type, to::Type) = typejoin(from, to)

function infer(e)
  g = EGraph{Expr,Type}(e)
  g[g.root].data
end


ex1 = :(cos(1 + 3.0) + 4 + (4 - 4im))
ex2 = :("ciao" * 2)
ex3 = :("ciao" * " mondo")

@test Complex == infer(ex1)
@test String == infer(ex3)
