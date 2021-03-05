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

calc = @theory begin
    ((p == q) == r)     ==  (p == (q == r))
    (p == q)            ==  (q == p)
    (q == q)            ==  true
    ¬(true)             ==  false
    ¬(p == q)           ==  (¬(p) == q)
    (p != q)            ==  ¬(p == q)

    ((p ∨ q) ∨ r)       ==  (p ∨ (q ∨ r))
    (p ∨ q)             ==  (q ∨ p)
    (p ∨ p)             ==  p
    (p ∨ (q == r))      ==  (p ∨ q == p ∨ r)
    (p ∨ ¬(p))          ==  true

    (p && q)            ==  ((p == q) == p ∨ q)

    (p => q)            ==  ((p ∨ q) == q)
    (p <= q)            ==  (q => p)
end

# g = EGraph(:(~p == p == false))
# saturate!(g, calc)

@test @areequal calc true ((¬p == p) == false)

g = EGraph(:((p ∨ q) ∧ (p => r) ∧ (q => r) => r))
saturate!(g, calc; timeout=5)
display(g.M); println()
