using Metatheory
using Metatheory.Library
using Metatheory.EGraphs
using Metatheory.EGraphs.Schedulers
using TermInterface

abstract type TypeAnalysis <: AbstractAnalysis end

function EGraphs.make(an::Type{TypeAnalysis}, g::EGraph, n::ENodeTerm)
  Any
end

function EGraphs.make(an::Type{TypeAnalysis}, g::EGraph, n::ENodeLiteral)
  v = n.value
  if v == :im
    typeof(im)
  else
    typeof(v)
  end
end

function EGraphs.make(an::Type{TypeAnalysis}, g::EGraph, n::ENodeTerm{Expr})
  if exprhead(n) != :call
    t = Any
    return t
  end
  sym = operation(n)
  if !(sym isa Symbol)
    t = Any
    return t
  end

  symval = getfield(@__MODULE__, sym)
  child_classes = map(x -> g[x], arguments(n))
  child_types = Tuple(map(x -> getdata(x, an, Any), child_classes))

  # t = t_arr[1]
  t = Core.Compiler.return_type(symval, child_types)

  if t == Union{}
    throw(MethodError(symval, child_types))
  end
  return t
end

EGraphs.join(an::Type{TypeAnalysis}, from, to) = typejoin(from, to)

EGraphs.islazy(x::Type{TypeAnalysis}) = true

function infer(e)
  g = EGraph(e)
  analyze!(g, TypeAnalysis)
  getdata(g[g.root], TypeAnalysis)
end
