using Metatheory
using Metatheory.Library
using Metatheory.EGraphs
using Metatheory.EGraphs.Schedulers
using TermInterface

function customlt(x, y)
  if typeof(x) == Expr && typeof(y) == Expr
    false
  elseif typeof(x) == typeof(y)
    isless(x, y)
  elseif x isa Symbol && y isa Number
    false
  elseif x isa Expr && y isa Number
    false
  elseif x isa Expr && y isa Symbol
    false
  else
    true
  end
end

canonical_t = @theory begin
  # restore n-arity
  (x * x)           => x^2
  (x^n::Number * x) => x^(n + 1)
  (x * x^n::Number) => x^(n + 1)
  (x + (+)(ys...))  => +(x, ys...)
  ((+)(xs...) + y)  => +(xs..., y)
  (x * (*)(ys...))  => *(x, ys...)
  ((*)(xs...) * y)  => *(xs..., y)

  (*)(xs...) |> Expr(:call, :*, sort!(xs; lt = customlt)...)
  (+)(xs...) |> Expr(:call, :+, sort!(xs; lt = customlt)...)
end


function simplcost(n::ENodeTerm, g::EGraph, an::Type{<:AbstractAnalysis})
  cost = 0 + arity(n)
  if operation(n) == :∂
    cost += 20
  end
  for id in arguments(n)
    eclass = g[id]
    !hasdata(eclass, an) && (cost += Inf; break)
    cost += last(getdata(eclass, an))
  end
  return cost
end

simplcost(n::ENodeLiteral, g::EGraph, an::Type{<:AbstractAnalysis}) = 0

function simplify(ex; steps = 4)
  params = SaturationParams(
    scheduler = ScoredScheduler,
    eclasslimit = 5000,
    timeout = 7,
    schedulerparams = (1000, 5, Schedulers.exprsize),
    #stopwhen=stopwhen,
  )
  hist = UInt64[]
  push!(hist, hash(ex))
  for i in 1:steps
    g = EGraph(ex)
    saturate!(g, cas, params)
    ex = extract!(g, simplcost)
    ex = rewrite(ex, canonical_t)
    if !TermInterface.istree(ex)
      return ex
    end
    if hash(ex) ∈ hist
      return ex
    end
    push!(hist, hash(ex))
  end

end
macro simplify(ex)
  Meta.quot(simplify(ex))
end
