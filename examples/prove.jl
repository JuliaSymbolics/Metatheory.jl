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
  for _ in 1:steps
    g = EGraph(ex)

    ids = [addexpr!(g, true), g.root]

    params.goal = (g::EGraph) -> in_same_class(g, ids...)
    saturate!(g, t, params)
    ex = extract!(g, astsize)
    if !TermInterface.isexpr(ex)
      return ex
    end
  end
  return ex
end

