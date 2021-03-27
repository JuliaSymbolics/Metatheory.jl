using Metatheory
using Test
using Metatheory.Library
using Metatheory.EGraphs
using Metatheory.Classic
using Metatheory.Util
using Metatheory.EGraphs.Schedulers

@metatheory_init ()

t = [
    RewriteRule(PatAllTerm(PatVar(:f), [PatVar(:a), PatVar(:b)], (;iscall=true)), PatLiteral(:matched))
]

g = EGraph(:(foo(bar)))
saturate!(g, t)

@test !areequal(g, RewriteRule[], :(foo(bar)), :matched)

addexpr!(g, :(foo(bar, baz)))
saturate!(g, t)

display(g.classes); println()

@test areequal(g, RewriteRule[], :(foo(bar,baz)), :matched)