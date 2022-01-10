using Metatheory
using TermInterface

function prove(t, ex, steps=1, timeout=10, eclasslimit=5000)
    params = SaturationParams(timeout=timeout, eclasslimit=eclasslimit, 
    scheduler=Schedulers.BackoffScheduler, schedulerparams=(6000,5))

    hist = UInt64[]
    push!(hist, hash(ex))
    for i ∈ 1:steps
        g = EGraph(ex)

        exprs = [true, g[g.root]]
        ids = [addexpr!(g, e)[1].id for e in exprs]

        goal=EqualityGoal(exprs, ids)
        params.goal = goal
        saturate!(g, t, params)
        ex = extract!(g, astsize)
        println(ex)
        if !TermInterface.istree(typeof(ex))
            return ex
        end
        if hash(ex) ∈ hist
            println("loop detected")
            return ex
        end
        push!(hist, hash(ex))
    end
    return ex
end


or_alg = @theory p q r begin
    ((p ∨ q) ∨ r)       ==  (p ∨ (q ∨ r))
    (p ∨ q)             ==  (q ∨ p)
    (p ∨ p)             -->  p
    (p ∨ true)          -->  true
    (p ∨ false)         -->  p
end

and_alg = @theory p q r begin
    ((p ∧ q) ∧ r)       ==  (p ∧ (q ∧ r))
    (p ∧ q)             ==  (q ∧ p)
    (p ∧ p)             -->  p
    (p ∧ true)          -->  p
    (p ∧ false)         -->  false
end

comb = @theory p q r begin
    # DeMorgan
    ¬(p ∨ q)            ==  (¬p ∧ ¬q)
    ¬(p ∧ q)            ==  (¬p ∨ ¬q)
    # distrib
    (p ∧ (q ∨ r))       ==  ((p ∧ q) ∨ (p ∧ r))
    (p ∨ (q ∧ r))       ==  ((p ∨ q) ∧ (p ∨ r))
    # absorb
    (p ∧ (p ∨ q))       -->  p
    (p ∨ (p ∧ q))       -->  p
    # complement
    (p ∧ (¬p ∨ q))      -->  p ∧ q
    (p ∨ (¬p ∧ q))      -->  p ∨ q
end

negt = @theory p begin
    (p ∧ ¬p)            -->  false
    (p ∨ ¬(p))          -->  true
    ¬(¬p)               ==  p
end

impl = @theory p q begin
    (p == ¬p)           -->  false
    (p == p)            -->  true
    (p == q)            -->  (¬p ∨ q) ∧ (¬q ∨ p)
    (p => q)            -->  (¬p ∨ q)
end

fold = @theory p q begin
    (p::Bool == q::Bool)   => (p == q)
    (p::Bool ∨ q::Bool)    => (p || q)
    (p::Bool => q::Bool)   => ((p || q) == q)
    (p::Bool ∧ q::Bool)    => (p && q)
    ¬(p::Bool)             => (!p)
end

prop_logic_theory = or_alg ∪ and_alg ∪ comb ∪ negt ∪ impl ∪ fold
    

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


using Metatheory

calc = @theory p q r begin
    ((p == q) == r)     ==  (p == (q == r))
    (p == q)            ==  (q == p)
    (q == q)            -->  true

    ¬(p == q)           ==  (¬(p) == q)
    (p != q)            ==  ¬(p == q)

    ((p ∨ q) ∨ r)       ==  (p ∨ (q ∨ r))
    (p ∨ q)             ==  (q ∨ p)
    (p ∨ p)             -->  p
    (p ∨ (q == r))      ==  (p ∨ q == p ∨ r)
    (p ∨ ¬(p))          -->  true

    # DeMorgan
    ¬(p ∨ q)            ==  (¬p ∧ ¬q)
    ¬(p ∧ q)            ==  (¬p ∨ ¬q)

    (p ∧ q)             ==  ((p == q) == p ∨ q)

    (p => q)            ==  ((p ∨ q) == q)
    # (p => q)            ==  (¬p ∨ q)
    # (p <= q)            =>  (q => p)
end

calc_logic_theory = calc ∪ fold