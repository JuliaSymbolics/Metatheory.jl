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


T = [
  @rule :b * :B --> :ε
  @rule :a * :a --> :ε
  @rule (:b * :b) * :b --> :ε
  @rule :B * :B --> :B
  @rule (@rep (:a * :b) (*) 7) --> :ε
  @rule (@rep (:a * :b * :a * :B) (*) 7) --> :ε
]

G = Mid ∪ Massoc ∪ T

astsize_prefer_empty(n::VecExpr, op, costs)::Float64 = op == :ε ? 0 : astsize(n, op, costs)

function test_kb(expr, params = SaturationParams())
  g = EGraph(expr)
  saturate!(g, G, params)
  ex = extract!(g, astsize_prefer_empty)
  ex == :ε
end

@test test_kb(:(b * B))
@test test_kb(:(a * a * a * a))
@test test_kb(:(((((((a * b) * (a * b)) * (a * b)) * (a * b)) * (a * b)) * (a * b)) * (a * b)))
@test test_kb(
  :(a * b * a * a * a * b * b * b * a * B * B * B * B * a),
  SaturationParams(timeout = 5, scheduler = SimpleScheduler),
)

@test !test_kb(:(((((((a * b) * (a * b)) * (a * b)) * (a * b)) * (a * b)) * (a * b)) * (b * a)))
@test !test_kb(:(a * a * b * a))
@test !test_kb(
  :(a * b * b * a * a * b * b * b * a * B * B * B * B * a),
  SaturationParams(timeout = 5, scheduler = SimpleScheduler),
)





