using Test
using Metatheory
using TermInterface

function prove(t, ex, steps = 1, timeout = 10, eclasslimit = 5000)
  params = SaturationParams(
    timeout = timeout,
    eclasslimit = eclasslimit,
    # scheduler=Schedulers.ScoredScheduler, schedulerparams=(1000,5, Schedulers.exprsize))
    scheduler = Schedulers.BackoffScheduler,
    schedulerparams = (6000, 5),
  )

  hist = UInt64[]
  push!(hist, hash(ex))
  for i in 1:steps
    g = EGraph(ex)

    exprs = [true, g[g.root]]
    ids = [addexpr!(g, e) for e in exprs]

    goal = EqualityGoal(exprs, ids)
    params.goal = goal
    rep = saturate!(g, t, params)
    @show rep
    ex = extract!(g, astsize)
    if !TermInterface.istree(ex)
      return ex
    end
    if hash(ex) ∈ hist
      return ex
    end
    push!(hist, hash(ex))
  end
  return ex
end

function ⟹ end

fold = @theory p q begin
  (p::Bool == q::Bool) => (p == q)
  (p::Bool || q::Bool) => (p || q)
  (p::Bool ⟹ q::Bool)  => ((p || q) == q)
  (p::Bool && q::Bool) => (p && q)
  !(p::Bool)           => (!p)
end


@testset "Prop logic" begin
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
    # DeMorgan
    !(p || q) == (!p && !q)
    !(p && q) == (!p || !q)
    # distrib
    (p && (q || r)) == ((p && q) || (p && r))
    (p || (q && r)) == ((p || q) && (p || r))
    # absorb
    (p && (p || q)) --> p
    (p || (p && q)) --> p
    # complement
    (p && (!p || q)) --> p && q
    (p || (!p && q)) --> p || q
  end

  negt = @theory p begin
    (p && !p) --> false
    (p || !(p)) --> true
    !(!p) == p
  end

  impl = @theory p q begin
    (p == !p) --> false
    (p == p) --> true
    (p == q) --> (!p || q) && (!q || p)
    (p ⟹ q) --> (!p || q)
  end


  t = or_alg ∪ and_alg ∪ comb ∪ negt ∪ impl ∪ fold

  ex = rewrite(:(((p ⟹ q) && (r ⟹ s) && (p || r)) ⟹ (q || s)), impl)
  @test prove(t, ex, 5, 10, 5000)


  @test @areequal t true ((!p == p) == false)
  @test @areequal t true ((!p == !p) == true)
  @test @areequal t true ((!p || !p) == !p) (!p || p) !(!p && p)
  @test @areequal t p (p || p)
  @test @areequal t true ((p ⟹ (p || p)))
  @test @areequal t true ((p ⟹ (p || p)) == ((!(p) && q) ⟹ q)) == true

  # Frege's theorem
  @test @areequal t true (p ⟹ (q ⟹ r)) ⟹ ((p ⟹ q) ⟹ (p ⟹ r))

  # Demorgan's
  @test @areequal t true (!(p || q) == (!p && !q))

  # Consensus theorem
  @test @areequal t ((x && y) || (!x && z) || (y && z)) ((x && y) || (!x && z))
end

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
@testset "Calculational Logic" begin
  calc = @theory p q r begin
    # Associativity of ==: 
    ((p == q) == r) == (p == (q == r))
    # Symmetry of ==: 
    (p == q) == (q == p)
    # Identity of ==:
    (q == q) --> true
    # Excluded middle 
    # Distributivity of !:
    !(p == q) == (!(p) == q)
    # Definition of !=: 
    (p != q) == !(p == q)
    #Associativity of ||:
    ((p || q) || r) == (p || (q || r))
    # Symmetry of ||: 
    (p || q) == (q || p)
    # Idempotency of ||:
    (p || p) --> p
    # Distributivity of ||: 
    (p || (q == r)) == (p || q == p || r)
    # Excluded Middle:
    (p || !(p)) --> true

    # DeMorgan
    !(p || q) == (!p && !q)
    !(p && q) == (!p || !q)

    (p && q) == ((p == q) == p || q)

    (p ⟹ q) == ((p || q) == q)
    # (p ⟹ q)            ==  (!p || q)
    # (p ⟸q)            ⟹  (q ⟹ p)
  end

  # t = or_alg ∪ and_alg ∪ neg_alg ∪ demorgan ∪ and_or_distrib ∪
  #     absorption ∪ calc

  t = calc ∪ fold

  g = EGraph(:(((!p == p) == false)))
  saturate!(g, t)
  extract!(g, astsize)

  @test @areequal t true ((!p == p) == false)
  @test @areequal t true ((!p == !p) == true)
  @test @areequal t true ((!p || !p) == !p) (!p || p) !(!p && p)
  @test @areequal t true ((p ⟹ (p || p)) == true)
  params = SaturationParams(timeout = 12, eclasslimit = 10000, schedulerparams = (1000, 5))

  @test areequal(t, true, :(((p ⟹ (p || p)) == ((!(p) && q) ⟹ q)) == true); params = params)

  # Frege's theorem
  @test areequal(t, true, :((p ⟹ (q ⟹ r)) ⟹ ((p ⟹ q) ⟹ (p ⟹ r))); params = params)

  # Demorgan's
  @test @areequal t true (!(p || q) == (!p && !q))

  # Consensus theorem
  areequal(t, :((x && y) || (!x && z) || (y && z)), :((x && y) || (!x && z)); params = params)
end
