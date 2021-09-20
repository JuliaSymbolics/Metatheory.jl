using Metatheory
using Metatheory.NewSyntax
using Test
using Metatheory.Library
using Metatheory.EGraphs
using Metatheory.EGraphs.Schedulers

# ================= TEST PATEQUIV =====================

# :foo => :zoo ⟺ :foo in same class as :bar  

lhs = PatEquiv(Pattern(:foo), Pattern(:bar))
rhs = Pattern(:zoo)
q = RewriteRule(lhs, rhs) 


g = EGraph()
fooclass, _ = addexpr!(g, :foo)
barclass, _ = addexpr!(g, :bar)
zooclass, _ = addexpr!(g, :zoo)

# display(g.classes); println()
@test !(in_same_class(g, fooclass, zooclass))

saturate!(g, [q])

# display(g.classes); println()
@test !(in_same_class(g, fooclass, zooclass))

merge!(g, fooclass.id, zooclass.id)

# display(g.classes); println()
@test in_same_class(g, fooclass, zooclass)
