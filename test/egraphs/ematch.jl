using Metatheory
using Metatheory: OptBuffer
using Test
using Metatheory.Library

# Simple E-Matching

include("../../examples/prove.jl")

b = OptBuffer{UInt128}(10)

@testset "Simple Literal" begin
  r = @rule 2 --> true
  g = EGraph(2)

  @test r.ematcher_left!(g, 0, g.root, r.stack, b) == 1
end

@testset "Composite Ground Terms" begin
  r = @rule f(2, 3) --> true
  g = EGraph(:(f(2, 3)))

  @test r.ematcher_left!(g, 0, g.root, r.stack, b) == 1
  @test r.ematcher_left!(g, 0, Id(1), r.stack, b) == 0
  @test r.ematcher_left!(g, 0, Id(2), r.stack, b) == 0

  g = EGraph(:(f(2, 4)))

  @test r.ematcher_left!(g, 0, g.root, r.stack, b) == 0
  @test r.ematcher_left!(g, 0, Id(1), r.stack, b) == 0
  @test r.ematcher_left!(g, 0, Id(2), r.stack, b) == 0


  r = @rule f(2, h(3, 4)) --> true
  g = EGraph(:(f(2, h(3, 4))))

  @test r.ematcher_left!(g, 0, g.root, r.stack, b) == 1
  @test r.ematcher_left!(g, 0, Id(1), r.stack, b) == 0
  @test r.ematcher_left!(g, 0, Id(2), r.stack, b) == 0
end

@testset "Pattern Variables" begin
  g = EGraph(:(f(2, 1)))
  r = @rule ~a --> true

  @test r.ematcher_left!(g, 0, g.root, r.stack, b) == 1
  @test r.ematcher_left!(g, 0, Id(1), r.stack, b) == 1
  @test r.ematcher_left!(g, 0, Id(2), r.stack, b) == 1
end

@testset "Type Assertions" begin
  r = @rule ~a::Int --> true
  g = EGraph(:(f(2, 1)))
  @test r.ematcher_left!(g, 0, g.root, r.stack, b) == 0

  g = EGraph(:3)
  @test r.ematcher_left!(g, 0, g.root, r.stack, b) == 1

  new_id = addexpr!(g, :f)
  union!(g, g.root, new_id)

  new_id = addexpr!(g, 4)
  union!(g, g.root, new_id)

  @test r.ematcher_left!(g, 0, g.root, r.stack, b) == 2
end

@testset "Predicate Assertions" begin
  r = @rule ~a::iseven --> true
  Base.iseven(g, ec::EClass) =
    any(ec.nodes) do n
      h = v_head(n)
      if has_constant(g, h)
        c = get_constant(g, h)
        return c isa Number && iseven(c)
      end
      false
    end

  g = EGraph(:(f(2, 1)))
  @test r.ematcher_left!(g, 0, g.root, r.stack, b) == 0

  g = EGraph(:2)
  @test r.ematcher_left!(g, 0, g.root, r.stack, b) == 1

  g = EGraph(:3)
  @test r.ematcher_left!(g, 0, g.root, r.stack, b) == 0

  new_id = addexpr!(g, :f)
  union!(g, g.root, new_id)

  new_id = addexpr!(g, 4)
  union!(g, g.root, new_id)

  @test r.ematcher_left!(g, 0, g.root, r.stack, b) == 1
end


@testset "Non-Ground Terms" begin
  g = EGraph(:(f(2, 1)))
  r = @rule f(2, ~a) --> true

  @test r.ematcher_left!(g, 0, g.root, r.stack, b) == 1
  @test r.ematcher_left!(g, 0, Id(1), r.stack, b) == 0
  @test r.ematcher_left!(g, 0, Id(2), r.stack, b) == 0

  r = @rule f(~a, ~a) --> true
  @test r.ematcher_left!(g, 0, g.root, r.stack, b) == 0

  g = EGraph(:(f(2, 2)))
  @test r.ematcher_left!(g, 0, g.root, r.stack, b) == 1

  g = EGraph(:(f(h(3, 4), h(3, 4))))
  @test r.ematcher_left!(g, 0, g.root, r.stack, b) == 1
end


r = @theory begin
  max(~x, ~y) --> 2 * ~x % ~y
  max(~x, ~y) --> sin(~x)
  sin(~x) --> max(~x, ~x)
end
@testset "Basic Equalities 1" begin
  g = EGraph(:(max(b, c)))

  t2 = addexpr!(g, :(max(d, d)))
  saturate!(g, r)

  t1 = addexpr!(g, :(max(b, c)))

  @test !in_same_class(g, t1, t2)
end


r = @theory begin
  ~a * 1 --> :foo
  ~a * 2 --> :bar
  1 * ~a --> :baz
  2 * ~a --> :mag
end

@testset "Matching Literals" begin
  g = EGraph()
  ec_1 = addexpr!(g, :(a * 1))
  ec_2 = addexpr!(g, :(a * 2))
  ec_1r = addexpr!(g, :(1 * a))
  ec_2r = addexpr!(g, :(2 * a))
  ec_foo = addexpr!(g, :foo)
  ec_bar = addexpr!(g, :bar)
  ec_baz = addexpr!(g, :baz)
  ec_mag = addexpr!(g, :mag)

  saturate!(g, r)

  @test in_same_class(g, ec_1, ec_foo)
  @test !in_same_class(g, ec_2, ec_foo)
  @test !in_same_class(g, ec_1, ec_bar)
  @test in_same_class(g, ec_2, ec_bar)

  @test in_same_class(g, ec_1r, ec_baz)
  @test in_same_class(g, ec_2r, ec_mag)
  @test !in_same_class(g, ec_2r, ec_baz)
  @test !in_same_class(g, ec_1r, ec_mag)
end


@testset "Matching Literals in Dynamic Rules" begin
  g = EGraph()

  ec_xy = addexpr!(g, :(x + y))
  ec_1 = addexpr!(g, 1)
  union!(g, ec_xy, ec_1)
  # 1: x
  # 2: y
  # 3: %1 + %2, 1

  r2 = @theory a b begin
    a::Number => :($a + 0)
    :x + :y => :y
  end
  saturate!(g, r2)
end


comm_monoid = @commutative_monoid (*) 1

@testset "Basic Equalities - Commutative Monoid" begin
  @test test_equality(comm_monoid, :(a * (c * (1 * d))), :(c * (1 * (d * a))))
  @test test_equality(comm_monoid, :(x * y), :(y * x))
  @test test_equality(comm_monoid, :((x * x) * (x * 1)), :(x * (x * x)))
end


comm_group = @commutative_group (+) 0 inv
t = comm_monoid ∪ comm_group ∪ (@distrib (*) (+))

@testset "Basic Equalities - Comm. Monoid, Abelian Group, Distributivity" begin
  @test test_equality(t, :((a * b) + (a * c)), :(a * (b + c)))
  @test test_equality(t, :(a * (c * (1 * d))), :(c * (1 * (d * a))))
  @test test_equality(t, :(a + (b * (c * d))), :(((d * c) * b) + a))
  @test test_equality(t, :((x + y) * (a + b)), :((a * (x + y)) + b * (x + y)), :((x * (a + b)) + y * (a + b)))
  @test test_equality(t, :(((x * a + x * b) + y * a) + y * b), :((x + y) * (a + b)))
  @test test_equality(t, :(a + (b * (c * d))), :(((d * c) * b) + a))
  @test test_equality(t, :(a + inv(a)), 0, :((x * y) + inv(x * y)), :(1 * 0))
end

@testset "Basic Equalities - False statements" begin
  @test !test_equality(t, :((a * b) + (a * c)), :(a * (b + a)))
  @test !test_equality(t, :((a * c) + (a * c)), :(a * (b + c)))
  @test !test_equality(t, :(a * (c * c)), :(c * (1 * (d * a))))
  @test !test_equality(t, :(c + (b * (c * d))), :(((d * c) * b) + a))
  @test !test_equality(t, :((x + y) * (a + c)), :((a * (x + y)) + b * (x + y)))
  @test !test_equality(t, :((x * (a + b)) + y * (a + b)), :((x + y) * (a + c)))
  @test !test_equality(t, :(((x * a + x * b) + y * a) + y * b), :((x + y) * (a + x)))
  @test !test_equality(t, :(a + (b * (c * a))), :(((d * c) * b) + a))
  @test !test_equality(t, :(a + inv(a)), :a)
  @test !test_equality(t, :((x * y) + inv(x * y)), 1)
end

# Issue 21
simp_theory = @theory begin
  sin() => :foo
end
g = EGraph(:(sin()))
saturate!(g, simp_theory)
@test extract!(g, astsize) == :foo

module Bar
var = :bar
using Metatheory

t = @theory begin
  woo(:foo) => var
end
end

module Foo
var = :foo
using Metatheory

t = @theory begin
  woo(:foo) => var
end
end


g = EGraph{Expr}(:(woo(foo)));
saturate!(g, Bar.t);
saturate!(g, Foo.t);

@testset "Different modules" begin
  @test in_same_class(g, addexpr!(g, :foo), addexpr!(g, :bar))
end


comm_monoid = @theory begin
  ~a * ~b --> ~b * ~a
  ~a * 1 --> ~a
  ~a * (~b * ~c) --> (~a * ~b) * ~c
  ~a::Number * ~b::Number => ~a * ~b
end

G = EGraph(:(3 * 4))
@testset "Basic Constant Folding Example - Commutative Monoid" begin
  @test test_equality(comm_monoid, :(3 * 4), 12)
  @test test_equality(comm_monoid, :(3 * 4), 12, :(4 * 3), :(6 * 2))
end


@testset "Basic Constant Folding Example 2 - Commutative Monoid" begin
  ex = :(a * 3 * b * 4)
  g = EGraph(ex)
  ids = [addexpr!(g, e) for e in (:((3a) * (4b)), :((12a) * b), :(((6 * 2) * b) * a))]
  saturate!(g, comm_monoid)
  @test in_same_class(g, ids...)
end

@testset "Type Assertions in Ematcher" begin
  some_theory = @theory begin
    ~a * ~b --> ~b * ~a
    ~a::Number * ~b::Number --> sin(~a, ~b)
    ~a::Int64 * ~b::Int64 --> cos(~a, ~b)
    ~a * (~b * ~c) --> (~a * ~b) * ~c
  end

  g = EGraph(:(2 * 3))
  saturate!(g, some_theory)

  @test test_equality(some_theory, :(2 * 3), :(sin(2, 3)); g)
  @test test_equality(some_theory, :(sin(2, 3)), :(cos(3, 2)); g)
end


@testset "Predicates in Ematcher" begin
  g = EGraph(:(2 * 3))
  zero_id = addexpr!(g, 0)

  some_theory = @theory begin
    ~a::iszero * ~b --> 0
    ~a * ~b --> ~b * ~a
  end

  Base.iszero(g::EGraph, ec::EClass) = in_same_class(g, zero_id, ec.id)

  saturate!(g, some_theory)

  @test test_equality(some_theory, :(a * b * 0), 0)
end

@testset "Dynamic rule predicates in EMatcher" begin
  g = EGraph(:(2 * 3))
  zero_id = addexpr!(g, 0)

  some_theory = @theory begin
    ~a * ~b => 0 where (iszero(a) || iszero(b))
    ~a * ~b --> ~b * ~a
  end

  Base.iszero(ec::EClass) = in_same_class(g, zero_id, ec.id)

  saturate!(g, some_theory)

  @test test_equality(some_theory, :(a * b * 0), 0)
end

@testset "Inequalities" begin
  failme = @theory p begin
    p != !p
    :foo == !:foo
    :foo --> :bazoo
    :bazoo --> :wazoo
  end

  g = EGraph{Expr}(:foo)
  report = saturate!(g, failme)
  @test report.reason === :contradiction
end
