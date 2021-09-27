using Metatheory
using Metatheory.NewSyntax
using Metatheory.EGraphs
using Test

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
    (p::Bool == q::Bool)   |> (p == q)
    (p::Bool ∨ q::Bool)    |> (p || q)
    (p::Bool => q::Bool)   |> ((p || q) == q)
    (p::Bool ∧ q::Bool)    |> (p && q)
    ¬(p::Bool)             |> (!p)
end

t = or_alg ∪ and_alg ∪ comb ∪ negt ∪ impl ∪ fold
    