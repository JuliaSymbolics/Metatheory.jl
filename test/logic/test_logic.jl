include("prop_logic_theory.jl")
include("prover.jl")

ex = rewrite(:(((p => q) ∧ (r => s) ∧ (p ∨ r)) => (q ∨ s)), impl)
@test prove(t, ex, 3, 7)


@test @areequal t true ((¬p == p) == false)
@test @areequal t true ((¬p == ¬p) == true)
@test @areequal t true ((¬p ∨ ¬p) == ¬p) (¬p ∨ p) ¬(¬p ∧ p)
@test @areequal t true ((p => (p ∨ p)))
@test @areequal t true ((p => (p ∨ p)) == ((¬(p) ∧ q) => q)) == true

# Frege's theorem
@test @areequal t true (p => (q => r)) => ((p => q) => (p => r))

# Demorgan's
@test @areequal t true (¬(p ∨ q) == (¬p ∧ ¬q))

# Consensus theorem
@test @areequal t ((x ∧ y) ∨ (¬x ∧ z) ∨ (y ∧ z))   ((x ∧ y) ∨ (¬x ∧ z))

# @timev areequal(t, :((x ∧ y) ∨ (¬x ∧ z) ∨ (y ∧ z)), :((x ∧ y) ∨ (¬x ∧ z)))
# @timev areequal(t, :((x ∧ y) ∨ (¬x ∧ z) ∨ (y ∧ z)), :((x ∧ y) ∨ (¬babo ∧ z)))
# @timev areequalmagic(t, :((x ∧ y) ∨ (¬x ∧ z) ∨ (y ∧ z)),   :((x ∧ y) ∨ (¬x ∧ z)))
# @timev areequalmagic(t, :((x ∧ y) ∨ (¬x ∧ z) ∨ (y ∧ z)),   :((babo ∧ y) ∨ (¬x ∧ z)))

# TODO proof strategies?
# Constructive Dilemma

# @test @areequal (t ∪ [@rule :p => true]) true (((p => q) ∧ (r => s)) ∧ (p ∨ r)) => (q ∨ s)

# @test areequal(t, true, :(¬(((¬p ∨ q) ∧ (¬r ∨ s)) ∧ (p ∨ r)) ∨ (q ∨ s)))

# using Metatheory.EGraphs.Schedulers
# Metatheory.options.verbose = true
# Metatheory.options.printiter = true
# ex = rewrite(:(((p => q) ∧ (r => s) ∧ (p ∨ r)) => (q ∨ s)), impl)
# g = EGraph(ex)
# params = SaturationParams(timeout=10, eclasslimit=5000, scheduler=SimpleScheduler)#, scheduler=ScoredScheduler)
# @profview saturate!(g, t, params)


# ex = :((p ∧ q ∨ (¬q ∧ (p => r) ∧ q)) => (s ∧ q))
# prove(t, ex, 3)

# extran = addanalysis!(g, ExtractionAnalysis, astsize)
# ex = extract!(g, extran)
# println(ex)
# #
# #
# ex = rewrite(:(((p => q) ∧ (r => s) ∧ (p ∨ r)) => (q ∨ s)), impl)
# g = EGraph(ex)
# @timev areequal(g, t, ex, true; timeout=10, eclasslimit=5000, scheduler=ScoredScheduler, schedulerparams=(32, 1))
#

# @profiler saturate!(g, t; timeout=8, eclasslimit=5000)
# exit(0)

# ex = rewrite(:(((p => p) ∧ (r => z) ∧ (p ∨ r)) => (q ∨ s)), impl)
# @test false == prove(t, ex, 4)


# g = EGraph(:(((p => q) ∧ (r => s) ∧ (p ∨ r)) => (q ∨ s)))
# @time saturate!(g, t; timeout=30, eclasslimit=Inf)
#
# in_same_set(g.uf, g.root, addexpr!(g, true).id) |> println
#
# struct LogicAnalysis <: AbstractAnalysis
#     egraph::EGraph
#     logic_egraph::EGraph
# end

