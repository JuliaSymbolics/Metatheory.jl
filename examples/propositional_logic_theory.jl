# # Rewriting 

using Metatheory, TermInterface

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


# Sketch function for basic iterative saturation and extraction 
function prove(
  t,
  ex,
  steps = 1,
  timeout = 10,
  params = SaturationParams(
    timeout = timeout,
    scheduler = Schedulers.BackoffScheduler,
    schedulerparams = (6000, 5),
    timer = false,
  ),
)
  hist = UInt64[]
  push!(hist, hash(ex))
  for i in 1:steps
    g = EGraph(ex)

    ids = [addexpr!(g, true), g.root]

    params.goal = (g::EGraph) -> in_same_class(g, ids...)
    saturate!(g, t, params)
    ex = extract!(g, astsize)
    if !TermInterface.isexpr(ex)
      return ex
    end
    if hash(ex) ∈ hist
      return ex
    end
    push!(hist, hash(ex))
  end
  return ex
end

