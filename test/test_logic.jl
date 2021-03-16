
# Metatheory.options[:printiter] = true

or_alg = @theory begin
    ((p ∨ q) ∨ r)       ==  (p ∨ (q ∨ r))
    (p ∨ q)             ==  (q ∨ p)
    (p ∨ p)             =>  p
    (p ∨ true)          =>  true
    (p ∨ false)         =>  p
end

and_alg = @theory begin
    ((p ∧ q) ∧ r)       ==  (p ∧ (q ∧ r))
    (p ∧ q)             ==  (q ∧ p)
    (p ∧ p)             =>  p
    (p ∧ true)          =>  p
    (p ∧ false)         =>  false
end

comb = @theory begin
    # DeMorgan
    ¬(p ∨ q)            ==  (¬p ∧ ¬q)
    ¬(p ∧ q)            ==  (¬p ∨ ¬q)
    # distrib
    (p ∧ (q ∨ r))       ==  ((p ∧ q) ∨ (p ∧ r))
    (p ∨ (q ∧ r))       ==  ((p ∨ q) ∧ (p ∨ r))
    # absorb
    (p ∧ (p ∨ q))       =>  p
    (p ∨ (p ∧ q))       =>  p
    # complement
    (p ∧ (¬p ∨ q))      =>  p ∧ q
    (p ∨ (¬p ∧ q))      =>  p ∨ q
end

negt = @theory begin
    (p ∧ ¬p)            =>  false
    (p ∨ ¬(p))          =>  true
    ¬(¬p)               ==  p
end

impl = @theory begin
    (p == ¬p)           =>  false
    (p == p)            =>  true
    (p == q)            =>  (¬p ∨ q) ∧ (¬q ∨ p)
    (p => q)            =>  (¬p ∨ q)
end

fold = @theory begin
    (p::Bool == q::Bool)    |>     (p == q)
    (p::Bool ∨ q::Bool)     |>     (p || q)
    (p::Bool => q::Bool)    |>     ((p || q) == q)
    (p::Bool ∧ q::Bool)     |>     (p && q)
    ¬(p::Bool)              |>     (!p)
end

# t = or_alg ∪ and_alg ∪ neg_alg ∪ demorgan ∪ and_or_distrib ∪
#     absorption ∪ calc

t = or_alg ∪ and_alg ∪ comb ∪ negt ∪ impl ∪ fold

@test @areequal t true ((¬p == p) == false)
@test @areequal t true ((¬p == ¬p) == true)
@test @areequal t true ((¬p ∨ ¬p) == ¬p) (¬p ∨ p) ¬(¬p ∧ p)
@test @areequal t true ((p => (p ∨ p)) == true)
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
# FIXME
# Constructive Dilemma

# @test @areequal (t ∪ [@rule :p => true]) true (((p => q) ∧ (r => s)) ∧ (p ∨ r)) => (q ∨ s)

# @test areequal(t, true, :(¬(((¬p ∨ q) ∧ (¬r ∨ s)) ∧ (p ∨ r)) ∨ (q ∨ s)))

function prove(t, ex, steps)
    hist = UInt64[]
    push!(hist, hash(ex))
    for i ∈ 1:steps
        g = EGraph(ex)
        saturate!(g, t, timeout=8, sizeout=5300, schedulerparams=(8,2))
        extran = addanalysis!(g, ExtractionAnalysis, astsize)
        ex = extract!(g, extran)
        println(ex)
        if !TermInterface.istree(ex)
            return ex
        end
        if hash(ex) ∈ hist
            println("loop detected")
            return ex
        end
        push!(hist, hash(ex))
    end
end

ex = rewrite(:(((p => q) ∧ (r => s) ∧ (p ∨ r)) => (q ∨ s)), impl)
@test prove(t, ex, 2)

# using Metatheory.EGraphs.Schedulers
# # println(ex)
# ex = rewrite(:(((p => q) ∧ (r => s) ∧ (p ∨ r)) => (q ∨ s)), impl)
# g = EGraph(ex)
# @timev repo = saturate!(g, t; timeout=10, sizeout=2^15, scheduler=ScoredScheduler)
# println(repo)
#
# extran = addanalysis!(g, ExtractionAnalysis, astsize)
# ex = extract!(g, extran)
# println(ex)
# #
# #
# ex = rewrite(:(((p => q) ∧ (r => s) ∧ (p ∨ r)) => (q ∨ s)), impl)
# g = EGraph(ex)
# @timev areequal(g, t, ex, true; timeout=10, sizeout=2^15, scheduler=ScoredScheduler, schedulerparams=(32, 1))
#

# @profiler saturate!(g, t; timeout=8, sizeout=2^15)
# exit(0)

# ex = rewrite(:(((p => p) ∧ (r => z) ∧ (p ∨ r)) => (q ∨ s)), impl)
# @test false == prove(t, ex, 4)


# g = EGraph(:(((p => q) ∧ (r => s) ∧ (p ∨ r)) => (q ∨ s)))
# @time saturate!(g, t; timeout=30, sizeout=Inf)
#
# in_same_set(g.U, g.root, addexpr!(g, true).id) |> println
#
# struct LogicAnalysis <: AbstractAnalysis
#     egraph::EGraph
#     logic_egraph::EGraph
# end
