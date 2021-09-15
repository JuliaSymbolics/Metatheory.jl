using Test
using Metatheory
using Metatheory.NewSyntax 
@metatheory_init
using Metatheory.Library
using Metatheory.Util
using Metatheory.EGraphs
using Metatheory.EGraphs.Schedulers

Metatheory.options.printiter = true
Metatheory.options.verbose = true

function rep(x, op, n::Int)
    foldl((x, y) -> :(($op)($x, $y)), repeat([x], n))
end

rep(:a, :*, 3)

Mid = @theory begin 
    a * :ε => a
    :ε * a => a
end 

Massoc = @theory begin
    a * (b * c) => (a * b) * c
    (a * b) * c => a * (b * c) 
end 


T = [
    @rule :b * :B => :ε
    @rule :a * :a => :ε
    @rule :b * :b * :b => :ε
    @rule :B * :B => :B
    RewriteRule(Pattern(rep(:(:a * :b), :*, 7)), Pattern(:(:ε)))
    RewriteRule(Pattern(rep(:(:a * :b * :a * :B), :*, 12)), Pattern(:(:ε)))
]

G = Mid ∪ Massoc ∪ T
expr = :(a * b * a * a * a * b * b * b * a * B * B * B * B * a)

ex = expr
g = EGraph(expr)
params = SaturationParams(timeout=8, scheduler=BackoffScheduler)# , schedulerparams=(128,4))#, scheduler=SimpleScheduler)
@timev saturate!(g, G, params)
ex = extract!(g, astsize)
@test ex == :ε

another_expr = :(b * B)
g = EGraph(another_expr)
saturate!(g, G, params)

another_expr = :(a * a * a * a)
some_eclass, _ = addexpr!(g, another_expr)
saturate!(g, G, params)
ex = extract!(g, astsize; root=some_eclass.id)
@test ex == :ε