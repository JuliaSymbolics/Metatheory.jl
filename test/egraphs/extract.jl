
using Metatheory
using Metatheory.Library

comm_monoid = @commutative_monoid (*) 1

fold_mul = @theory begin
  ~a::Number * ~b::Number => ~a * ~b
end



@testset "Extraction 1 - Commutative Monoid" begin
  t = comm_monoid ∪ fold_mul
  g = EGraph(:(3 * 4))
  saturate!(g, t)
  @test (12 == extract!(g, astsize))

  ex = :(a * 3 * b * 4)
  g = EGraph(ex)
  params = SaturationParams(timeout = 15)
  saturate!(g, t, params)
  extr = extract!(g, astsize)
  @test extr == :((12 * a) * b) ||
        extr == :(12 * (a * b)) ||
        extr == :(a * (b * 12)) ||
        extr == :((a * b) * 12) ||
        extr == :((12a) * b) ||
        extr == :(a * (12b)) ||
        extr == :((b * (12a))) ||
        extr == :((b * 12) * a) ||
        extr == :((b * a) * 12) ||
        extr == :(b * (a * 12)) ||
        extr == :((12b) * a)
end

fold_add = @theory begin
  ~a::Number + ~b::Number => ~a + ~b
end

@testset "Extraction 2" begin
  comm_group = @commutative_group (+) 0 inv


  t = comm_monoid ∪ comm_group ∪ (@distrib (*) (+)) ∪ fold_mul ∪ fold_add

  ex = :((x * (a + b)) + (y * (a + b)))
  g = EGraph(ex)
  saturate!(g, t)
  extract!(g, astsize) == :((y + x) * (b + a))
end

comm_monoid = @commutative_monoid (*) 1

comm_group = @commutative_group (+) 0 inv

powers = @theory begin
  ~a * ~a → (~a)^2
  ~a → (~a)^1
  (~a)^~n * (~a)^~m → (~a)^(~n + ~m)
end
logids = @theory begin
  log((~a)^~n) --> ~n * log(~a)
  log(~x * ~y) --> log(~x) + log(~y)
  log(1) --> 0
  log(:e) --> 1
  :e^(log(~x)) --> ~x
end

@testset "Extraction 3" begin
  g = EGraph(:(log(e)))
  params = SaturationParams(timeout = 9)
  saturate!(g, logids, params)
  @test extract!(g, astsize) == 1
end

t = comm_monoid ∪ comm_group ∪ (@distrib (*) (+)) ∪ powers ∪ logids ∪ fold_mul ∪ fold_add

@testset "Complex Extraction" begin
  g = EGraph(:(log(e) * log(e)))
  params = SaturationParams(timeout = 9)
  saturate!(g, t, params)
  @test extract!(g, astsize) == 1

  g = EGraph(:(log(e) * (log(e) * e^(log(3)))))
  params = SaturationParams(timeout = 7)
  saturate!(g, t, params)
  @test extract!(g, astsize) == 3


  g = EGraph(:(a^3 * a^2))
  saturate!(g, t)
  ex = extract!(g, astsize)
  @test ex == :(a^5)

  g = EGraph(:(a^3 * a^2))
  saturate!(g, t)
  ex = extract!(g, astsize)
  @test ex == :(a^5)
end

@testset "Custom Cost Function 1" begin
  function cust_astsize(n::VecExpr, head, children_costs::Vector{Float64})::Float64
    v_isexpr(n) || return 1
    cost = 1 + v_arity(n)

    if head == :^
      cost += 2
    end

    cost + sum(children_costs)
  end

  g = EGraph(:((log(e) * log(e)) * (log(a^3 * a^2))))
  saturate!(g, t)
  ex = extract!(g, cust_astsize)
  @test ex == :(5 * log(a)) || ex == :(log(a) * 5)
end

@testset "Symbols in Right hand" begin
  expr = :(a * (a * (b * (a * b))))
  g = EGraph(expr)

  a_id = addexpr!(g, :a)

  function costfun(n::VecExpr, op, children_costs::Vector{Float64})::Float64
    v_isexpr(n) || return 1
    v_arity(n) == 2 || return 1

    left = v_children(n)[1]
    in_same_class(g, left, a_id) ? 1 : 100
  end


  moveright = @theory begin
    (:b * (:a * ~c)) --> (:a * (:b * ~c))
  end

  res = rewrite(expr, moveright)

  saturate!(g, moveright)
  resg = extract!(g, costfun)

  @test resg == res == :(a * (a * (a * (b * b))))
end

@testset "Consistency with classical backend" begin
  co = @theory begin
    sum(~x ⋅ :bazoo ⋅ :woo) --> sum(:n * ~x)
  end

  ex = :(sum(wa(rio) ⋅ bazoo ⋅ woo))
  g = EGraph(ex)
  saturate!(g, co)

  res = extract!(g, astsize)
  resclassic = rewrite(ex, co)

  @test res == resclassic
end


@testset "No arguments" begin
  ex = :(f())
  g = EGraph(ex)
  @test :(f()) == extract!(g, astsize)

  ex = :(sin() + cos())

  t = @theory begin
    sin() + cos() --> tan()
  end

  gg = EGraph(ex)
  saturate!(gg, t)
  res = extract!(gg, astsize)

  @test res == :(tan())
end


@testset "Symbol or function object operators in expressions in EGraphs" begin
  ex = :(($+)(x, y))
  t = [@rule a b a + b => 2]
  g = EGraph(ex)
  saturate!(g, t)
  @test extract!(g, astsize) == 2
end
