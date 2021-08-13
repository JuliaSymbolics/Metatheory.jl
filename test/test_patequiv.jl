using Metatheory
using Test
using Metatheory.Library
using Metatheory.EGraphs
using Metatheory.Util
using Metatheory.EGraphs.Schedulers

@metatheory_init ()

# ================= TEST PATEQUIV =====================

# :foo => :zoo ⟺ :foo in same class as :bar  

lhs = PatEquiv(@pat(:foo), @pat(:bar))
rhs = @pat :zoo
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
