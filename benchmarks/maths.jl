# include("eggify.jl")
using Metatheory
using Metatheory.Library
using Metatheory.EGraphs.Schedulers

mult_t = @commutative_monoid (*) 1
plus_t = @commutative_monoid (+) 0

minus_t = @theory a b begin
  a - a --> 0
  a + (-b) --> a - b
end

mulplus_t = @theory a b c begin
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
  inv(x) == x^(-1)
end

function customlt(x, y)
  if typeof(x) == Expr && Expr == typeof(y)
    false
  elseif typeof(x) == typeof(y)
    isless(x, y)
  elseif x isa Symbol && y isa Number
    false
  else
    true
  end
end

canonical_t = @theory x y xs ys begin
  # restore n-arity
  (x + (+)(ys...)) --> +(x, ys...)
  ((+)(xs...) + y) --> +(xs..., y)
  (x * (*)(ys...)) --> *(x, ys...)
  ((*)(xs...) * y) --> *(xs..., y)

  (*)(xs...) => Expr(:call, :*, sort!(xs; lt = customlt)...)
  (+)(xs...) => Expr(:call, :+, sort!(xs; lt = customlt)...)
end


cas = mult_t ∪ plus_t ∪ minus_t ∪ mulplus_t ∪ pow_t
theory = cas

query = Metatheory.cleanast(:(a + b + (0 * c) + d))


function simplify(ex, params)
  g = EGraph(ex)
  report = saturate!(g, cas, params)
  println(report)
  res = extract!(g, astsize)
  rewrite(res, canonical_t)
end

###########################################


params = SaturationParams(timeout = 20, schedulerparams = (1000, 5))

# params = SaturationParams(; timer = false)

params = SaturationParams()

simplify(:(a + b + (0 * c) + d), params)

@profview simplify(:(a + b + (0 * c) + d), params)

@profview_allocs simplify(:(a + b + (0 * c) + d), params)


@benchmark simplify(:(a + b + (0 * c) + d), params)


# open("src/main.rs", "w") do f
#   write(f, rust_code(theory, query))
# end

# @benchmark simplify(:(a + b + (0 * c) + d), params)
