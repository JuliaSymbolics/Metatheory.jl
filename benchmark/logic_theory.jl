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

    ids = [addexpr!(g, true), g.root]

    params.goal = (g::EGraph) -> in_same_class(g, ids...)
    saturate!(g, t, params)
    ex = extract!(g, astsize)
    if !Metatheory.istree(ex)
      return ex
    end
    if hash(ex) ∈ hist
      return ex
    end
    push!(hist, hash(ex))
  end
  return ex
end

logic_theory = or_alg ∪ and_alg ∪ comb ∪ negt ∪ impl ∪ fold
