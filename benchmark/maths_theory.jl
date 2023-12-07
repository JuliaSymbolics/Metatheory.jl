
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


maths_theory = mult_t ∪ plus_t ∪ minus_t ∪ mulplus_t ∪ pow_t

postprocess_maths(x) = rewrite(x, canonical_t)



