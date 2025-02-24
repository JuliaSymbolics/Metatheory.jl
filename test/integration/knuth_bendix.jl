using Test
using Metatheory
using Metatheory.Library
using Metatheory.EGraphs
using Metatheory.Rules
using Metatheory.EGraphs.Schedulers

function rep(x, op, n::Int)
  foldl((x, y) -> :(($op)($x, $y)), repeat([x], n))
end

macro rep(x, op, n::Int)
  expr = rep(x, op, n)
  esc(expr)
end

rep(:a, :*, 3)

@rule (@rep :a (*) 3) => :b

Mid = @theory a begin
  a * :ε --> a
  :ε * a --> a
end

Massoc = @theory a b c begin
  a * (b * c) == (a * b) * c
  # (a * b) * c --> a * (b * c)
end


macro kb_theory_237_abab(n)
  quote
    T = [
      @rule :b * :B --> :ε
      @rule :a * :a --> :ε
      @rule (:b * :b) * :b --> :ε
      @rule :B * :B --> :B
      @rule (@rep (:a * :b) (*) 7) --> :ε
      @rule (@rep (:a * :b * :a * :B) (*) $n) --> :ε
    ]
    group_theory = Mid ∪ Massoc ∪ T
  end |> esc
end

@kb_theory_237_abab 5

astsize_prefer_empty(n::VecExpr, op, costs)::Float64 = op == :ε ? 0 : astsize(n, op, costs)

function test_kb(expr, t, params = SaturationParams())
  g = EGraph(expr)
  saturate!(g, t, params)
  ex = extract!(g, astsize_prefer_empty)

  # TODO: Check if group is trivial
  # a = addexpr!(g, :a)
  # b = addexpr!(g, :b)
  # B = addexpr!(g, :B)
  # ε = addexpr!(g, :ε)
  # @show in_same_class(g, a, ε)
  # @show in_same_class(g, b, ε)
  # @show in_same_class(g, B, ε)
  ex == :ε
end


for n in 5:8
  t = @eval @kb_theory_237_abab $n

  @test test_kb(:(b * B), group_theory)
  @test test_kb(:(a * a * a * a), group_theory)
  @test test_kb(:(((((((a * b) * (a * b)) * (a * b)) * (a * b)) * (a * b)) * (a * b)) * (a * b)), group_theory)
  @test test_kb(
    :(a * b * a * a * a * b * b * b * a * B * B * B * B * a),
    group_theory,
    SaturationParams(timeout = 5, scheduler = SimpleScheduler),
  )

  @test !test_kb(:(((((((a * b) * (a * b)) * (a * b)) * (a * b)) * (a * b)) * (a * b)) * (b * a)), group_theory)
  @test !test_kb(:(a * a * b * a), group_theory)
  @test !test_kb(
    :(a * b * b * a * a * b * b * b * a * B * B * B * B * a),
    group_theory,
    SaturationParams(timeout = 5, scheduler = SimpleScheduler),
  )
end
