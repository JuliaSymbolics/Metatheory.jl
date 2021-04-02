include("prop_logic_theory.jl")
include("prover.jl")

using Test

Metatheory.options.verbose = true

ex = rewrite(:(((p => q) ∧ (r => s) ∧ (p ∨ r)) => (q ∨ s)), impl)
@profview prove(t, ex, 2, 7)


using Metatheory
@metatheory_init ()
using Metatheory.EGraphs
using Metatheory.Library
using Metatheory.Util
using Metatheory.EGraphs.Schedulers

Metatheory.options.printiter = true
Metatheory.options.verbose = true

function rep(x, op, n::Int)
    foldl((x, y) -> :(($op)($x, $y)), repeat([x], n))
end

rep(:a, :*, 3)

Mid = @theory begin 
    a * :ε => :ε
    :ε * a => :ε
end 

Massoc = @theory begin
    a * (b * c) => (a * b) * c
    (a * b) * c => a * (b * c) 
end 


T = [
    @rule :b*:B => :ε
    RewriteRule(Pattern(rep(:(:a), :*, 2)), Pattern(:(:ε)))
    RewriteRule(Pattern(rep(:(:b), :*, 3)), Pattern(:(:ε)))
    RewriteRule(Pattern(rep(:(:a*:b), :*, 7)), Pattern(:(:ε)))
    RewriteRule(Pattern(rep(:(:a*:b*:a*:B), :*, 5)), Pattern(:(:ε)))
]

G = Mid∪Massoc∪T
expr = :(a*b*a*a*a*b*b*b*a*B*B*B*B*a)

g = EGraph(expr)
params = SaturationParams(timeout=5)
@profview saturate!(g, G, params)
ex = extract!(g, astsize)
rewrite(ex, Mid)


another_expr = :(a*a*a*a)
some_eclass = addexpr!(g, another_expr)
g.root = some_eclass.id
ex = extract!(g, astsize)