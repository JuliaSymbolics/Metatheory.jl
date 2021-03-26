using Metatheory
using Test
using Metatheory.Library
using Metatheory.EGraphs
using Metatheory.Classic
using Metatheory.Util
using Metatheory.EGraphs.Schedulers

@metatheory_init ()

# ================= TEST PATEQUIV =====================

# :foo => :zoo ⟺ :foo in same class as :bar  
lhs = @pat :foo
rhs = @pat :zoo
pat = PatEquiv(@pat(:foo), @pat(:bar))
q = MultiPatRewriteRule(lhs, rhs, [pat]) 


g = EGraph()
fooclass = addexpr!(g, :foo)
barclass = addexpr!(g, :bar)
zooclass = addexpr!(g, :zoo)

# display(g.classes); println()
@test !(in_same_class(g, fooclass, zooclass))

saturate!(g, [q])

# display(g.classes); println()
@test !(in_same_class(g, fooclass, zooclass))

merge!(g, fooclass.id, zooclass.id)

# display(g.classes); println()
@test in_same_class(g, fooclass, zooclass)


# =====================================================

# Zen Lineage Chart Example from Julog.jl https://github.com/ztangent/Julog.jl
# clauses = @julog [
#   ancestor(sakyamuni, bodhidharma) <<= true,
#   teacher(bodhidharma, huike) <<= true,
#   teacher(huike, sengcan) <<= true,
#   teacher(sengcan, daoxin) <<= true,
#   teacher(daoxin, hongren) <<= true,
#   teacher(hongren, huineng) <<= true,
#   ancestor(A, B) <<= teacher(A, B),
#   ancestor(A, C) <<= teacher(B, C) & ancestor(A, B),
#   grandteacher(A, C) <<= teacher(A, B) & teacher(B, C)
# ]

facts = [
    :(ancestor(sakyamuni, bodhidharma)),
    :(teacher(bodhidharma, huike)),
    :(teacher(huike, sengcan)),
    :(teacher(sengcan, daoxin)),
    :(teacher(daoxin, hongren)),
    :(teacher(hongren, huineng)),
]

function addfacts!(g::EGraph, facts)
    for fact ∈ facts 
        fc = addexpr!(g, fact)
        tc = addexpr!(g, true)
        merge!(g, fc.id, tc.id)
    end
end

clauses = @theory begin 
    teacher(a, b) => ancestor(a, b)
    # grandteacher(A, C) <<= teacher(A, B) & teacher(B, C)
end 

# TODO syntax for MultiPatRewriteRule and PatEquiv
#   ancestor(A, C) <<= teacher(B, C) & ancestor(A, B),
lhs = @pat teacher(b, c)
rhs = @pat ancestor(a,c)
pat1 = PatEquiv((@pat ancestor(a, b)), @pat teacher(b,c))
q = MultiPatRewriteRule(lhs, rhs, [pat1]) 

push!(clauses, q)

# goals to prove: ancestor(sakyamuni, huineng)
g = EGraph()
addfacts!(g, facts)

query = :(ancestor(sakyamuni, huineng))
addexpr!(g, query)

params = SaturationParams(timeout=14)
saturate!(g, clauses, params)

# display(g.classes); println()

emptyt = @theory begin end
@test areequal(g, emptyt, true, query)
