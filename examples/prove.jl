# Sketch function for basic iterative saturation and extraction
function prove(
  t,
  ex,
  steps = 1,
  timeout = 10,
  params = SaturationParams(
    timeout = timeout,
    scheduler = Schedulers.BackoffScheduler,
    schedulerparams = (match_limit = 6000, ban_length = 5),
    timer = false,
  ),
)
  for _ in 1:steps
    g = EGraph(ex)

    ids = [addexpr!(g, true), g.root]

    params.goal = (g::EGraph) -> in_same_class(g, ids...)
    saturate!(g, t, params)
    ex = extract!(g, astsize)
  end
  return ex
end

function test_equality(t, exprs...; params = SaturationParams(), g = EGraph())
  length(exprs) == 1 && return true
  ids = [addexpr!(g, ex) for ex in exprs]
  params = deepcopy(params)
  params.goal = (g::EGraph) -> in_same_class(g, ids...)

  report = saturate!(g, t, params)
  goal_reached = params.goal(g)

  if !(report.reason === :saturated) && !goal_reached
    return false # failed to prove
  end
  return goal_reached
end
