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
  a * (b * c) --> (a * b) * c
  (a * b) * c --> a * (b * c)
end


T = [
  @rule :b * :B --> :ε
  @rule :a * :a --> :ε
  @rule :b * :b * :b --> :ε
  @rule :B * :B --> :B
  @rule (@rep (:a * :b) (*) 7) --> :ε
  @rule (@rep (:a * :b * :a * :B) (*) 7) --> :ε
  # RewriteRule(makepattern(rep(:(:a * :b), :*, 7)), :ε)
  # RewriteRule(makepattern(rep(:(:a * :b * :a * :B), :*, 12)), :ε)
]

G = Mid ∪ Massoc ∪ T
expr = :(a * b * a * a * a * b * b * b * a * B * B * B * B * a)

ex = expr
g = EGraph(expr)
params = SaturationParams(timeout = 9, scheduler = BackoffScheduler)# , schedulerparams=(128,4))#, scheduler=SimpleScheduler)
@timev saturate!(g, G, params)
ex = extract!(g, astsize)
@test ex == :ε

another_expr = :(b * B)
g = EGraph(another_expr)
saturate!(g, G, params)

another_expr = :(a * a * a * a)
some_eclass, _ = addexpr!(g, another_expr)
saturate!(g, G, params)
ex = extract!(g, astsize; root = some_eclass.id)
@test ex == :ε
