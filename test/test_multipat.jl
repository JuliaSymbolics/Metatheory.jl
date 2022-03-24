using Metatheory
using Test
using Metatheory.Library
using Metatheory.EGraphs
using Metatheory.EGraphs.Schedulers


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
  for fact in facts
    fc, _ = addexpr!(g, fact)
    tc, _ = addexpr!(g, true)
    merge!(g, fc.id, tc.id)
  end
end

clauses = @theory begin
  teacher(a, b) => ancestor(a, b)
  # grandteacher(A, C) <<= teacher(A, B) & teacher(B, C)
end

# TODO syntax for MultiPatRewriteRule and PatEquiv
#   ancestor(A, C) <<= teacher(B, C) & ancestor(A, B),
lhs = Pattern(:(teacher(b, c)))
rhs = Pattern(:(ancestor(a, c)))
pat1 = PatEquiv(Pattern(:(ancestor(a, b))), Pattern(:(teacher(b, c))))
q = MultiPatRewriteRule(lhs, rhs, [pat1])

push!(clauses, q)

# goals to prove: ancestor(sakyamuni, huineng)
g = EGraph()
addfacts!(g, facts)

query = :(ancestor(sakyamuni, huineng))
addexpr!(g, query)

params = SaturationParams(timeout = 14)
saturate!(g, clauses, params)

display(g.classes);
println();

emptyt = @theory begin end
@test areequal(g, emptyt, true, query)
