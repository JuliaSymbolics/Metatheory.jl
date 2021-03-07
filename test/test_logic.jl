
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


# TODO proof strategies?
# FIXME
# Constructive Dilemma

# @test @areequal (t ∪ [@rule :p => true]) true (((p => q) ∧ (r => s)) ∧ (p ∨ r)) => (q ∨ s)

ex = rewrite(:(((p => q) ∧ (r => s) ∧ (p ∨ r)) => (q ∨ s)), impl)
println(ex)
g = EGraph(ex)
@timev saturate!(g, t; timeout=8, sizeout=2^15)
# exit(0)

extran = addanalysis!(g, ExtractionAnalysis, astsize)

ex = extract!(g, extran)
println(ex)

g = EGraph(ex)
@time saturate!(g, t; timeout=5, sizeout=2^12)
extran = addanalysis!(g, ExtractionAnalysis, astsize)

ex = extract!(g, extran)

@test ex == true


# g = EGraph(:(((p => q) ∧ (r => s) ∧ (p ∨ r)) => (q ∨ s)))
# @time saturate!(g, t; timeout=30, sizeout=Inf)
#
# in_same_set(g.U, g.root, addexpr!(g, true).id) |> println
#
# struct LogicAnalysis <: AbstractAnalysis
#     egraph::EGraph
#     logic_egraph::EGraph
# end
