# https://www.cs.cornell.edu/gries/Logic/Axioms.html
# The axioms of calculational propositional logic C are listed in the order in
# which they are usually presented and taught. Note that equivalence comes
# first. Note also that, after the first axiom, we take advantage of
# associativity of equivalence and write sequences of equivalences without
# parentheses. We use == for equivalence, | for disjunction, & for conjunction,
# ~ for negation (not), => for implication, and <= for consequence.
#
# Associativity of ==: ((p == q) == r) == (p == (q == r))
# Symmetry of ==: p == q == q == p
# Identity of ==: true == q == q
#
# Definition of false: false == ~true
# Distributivity of not: ~(p == q) == ~p == q
# Definition of =/=: (p =/= q) == ~(p == q)
#
# Associativity of |: (p | q) & r == p | (q | r)
# Symmetry of |: p | q == q | p
# Idempotency of |: p | p == p
# Distributivity of |: p |(q == r) == p | q == p | r
# Excluded Middle: p | ~p
#
# Golden rule: p & q == p == q == p | q
#
# Implication: p => q == p | q == q
# Consequence: p <= q == q => p

# Metatheory.options[:printiter] = true

calc = @theory begin
    ((p == q) == r)     ==  (p == (q == r))
    (p == q)            ==  (q == p)
    (q == q)            =>  true

    ¬(p == q)           ==  (¬(p) == q)
    (p != q)            ==  ¬(p == q)

    ((p ∨ q) ∨ r)       ==  (p ∨ (q ∨ r))
    (p ∨ q)             ==  (q ∨ p)
    (p ∨ p)             =>  p
    (p ∨ (q == r))      ==  (p ∨ q == p ∨ r)
    (p ∨ ¬(p))          =>  true

    # DeMorgan
    ¬(p ∨ q)            ==  (¬p ∧ ¬q)
    ¬(p ∧ q)            ==  (¬p ∨ ¬q)

    (p ∧ q)             ==  ((p == q) == p ∨ q)

    (p => q)            ==  ((p ∨ q) == q)
    # (p => q)            ==  (¬p ∨ q)
    # (p <= q)            =>  (q => p)
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

t = calc ∪ fold

@test @areequal t true ((¬p == p) == false)
@test @areequal t true ((¬p == ¬p) == true)
@test @areequal t true ((¬p ∨ ¬p) == ¬p) (¬p ∨ p) ¬(¬p ∧ p)
@test @areequal t true ((p => (p ∨ p)) == true)
@test @areequal t true ((p => (p ∨ p)) == ((¬(p) ∧ q) => q)) == true

# Frege's theorem
@test areequal(t, true, :((p => (q => r)) => ((p => q) => (p => r))); timeout=12, sizeout=2^15)

# Demorgan's
@test @areequal t true (¬(p ∨ q) == (¬p ∧ ¬q))

# Consensus theorem
@test_skip @areequal t ((x ∧ y) ∨ (¬x ∧ z) ∨ (y ∧ z))   ((x ∧ y) ∨ (¬x ∧ z))


# TODO proof strategies?

# Constructive Dilemma

# @test @areequal (t ∪ [@rule :p => true]) true ((p => q) ∧ (r => s) ∧ (p ∨ r)) => (q ∨ s)

#
# g = EGraph(:(((p => q) ∧ (r => s) ∧ (p ∨ r)) => (q ∨ s)))
# @time saturate!(g, t; timeout=10, sizeout=2^12)
# extran = addanalysis!(g, ExtractionAnalysis, astsize)
#
# println(extract!(g, extran))

#
# in_same_set(g.U, g.root, addexpr!(g, true).id) |> println
#
# struct LogicAnalysis <: AbstractAnalysis
#     egraph::EGraph
#     logic_egraph::EGraph
# end
