# # Rewriting 

using Metatheory
using Metatheory.TermInterface

fold = @theory p q begin
  (p::Bool == q::Bool) => (p == q)
  (p::Bool || q::Bool) => (p || q)
  (p::Bool ⟹ q::Bool)  => ((p || q) == q)
  (p::Bool && q::Bool) => (p && q)
  !(p::Bool)           => (!p)
end

or_alg = @theory p q r begin
  ((p || q) || r) == (p || (q || r))
  (p || q) == (q || p)
  (p || p) --> p
  (p || true) --> true
  (p || false) --> p
end

and_alg = @theory p q r begin
  ((p && q) && r) == (p && (q && r))
  (p && q) == (q && p)
  (p && p) --> p
  (p && true) --> p
  (p && false) --> false
end

comb = @theory p q r begin
  !(p || q) == (!p && !q)                   # DeMorgan
  !(p && q) == (!p || !q)
  (p && (q || r)) == ((p && q) || (p && r)) # Distributivity
  (p || (q && r)) == ((p || q) && (p || r))
  (p && (p || q)) --> p                     # Absorb
  (p || (p && q)) --> p
  (p && (!p || q)) --> p && q               # Complement
  (p || (!p && q)) --> p || q
end

negt = @theory p begin
  (p && !p) --> false
  (p || !(p)) --> true
  !(!p) --> p
end

impl = @theory p q begin
  (p == !p) --> false
  (p == p) --> true
  (p == q) --> (!p || q) && (!q || p)
  (p ⟹ q) --> (!p || q)
end

propositional_logic_theory = or_alg ∪ and_alg ∪ comb ∪ negt ∪ impl ∪ fold
