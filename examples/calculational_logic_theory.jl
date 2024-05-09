# ## Theory of Calculational Logic 
# https://www.cs.cornell.edu/gries/Logic/Axioms.html
# The axioms of calculational propositional logic C are listed in the order in
# which they are usually presented and taught. Note that equivalence comes
# first. Note also that, after the first axiom, we take advantage of
# associativity of equivalence and write sequences of equivalences without
# parentheses. We use == for equivalence, | for disjunction, & for conjunction,

# Golden rule: p & q == p == q == p | q
#
# Implication: p ⟹ q == p | q == q
# Consequence: p ⟸q == q ⟹ p

# Definition of false: false == !true 

fold = @theory p q begin
  (p::Bool == q::Bool) => (p == q)
  (p::Bool || q::Bool) => (p || q)
  (p::Bool ⟹ q::Bool)  => ((p || q) == q)
  (p::Bool && q::Bool) => (p && q)
  !(p::Bool)           => (!p)
end

calc = @theory p q r begin
  ((p == q) == r) == (p == (q == r))      # Associativity of ==: 
  (p == q) == (q == p)                    # Symmetry of ==: 
  (q == q) --> true                       # Identity of ==: 
  !(p == q) == (!(p) == q)                # Distributivity of !:
  (p != q) == !(p == q)                   # Definition of !=: 
  ((p || q) || r) == (p || (q || r))      # Associativity of ||:
  (p || q) == (q || p)                    # Symmetry of ||: 
  (p || p) --> p                          # Idempotency of ||:
  (p || (q == r)) == ((p || q) == (p || r))   # Distributivity of ||: 
  (p || !(p)) --> true                    # Excluded Middle:
  !(p || q) == (!p && !q)                 # DeMorgan
  !(p && q) == (!p || !q)
  (p && q) == ((p == q) == (p || q))
  (p ⟹ q) == ((p || q) == q)
end


calculational_logic_theory = calc ∪ fold
