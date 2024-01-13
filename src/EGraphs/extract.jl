struct Extractor{CostFun,Cost}
  g::EGraph
  cost_function::CostFun
  costs::Dict{Id,Tuple{Cost,Int64}} # Cost and index in eclass
end

"""
Given a cost function, extract the expression
with the smallest computed cost from an [`EGraph`](@ref)
"""
function Extractor(g::EGraph, cost_function::Function, cost_type = Float64)
  extractor = Extractor{typeof(cost_function),cost_type}(g, cost_function, Dict{Id,Tuple{cost_type,VecExpr}}())
  find_costs!(extractor)
  extractor
end

function extract_expr_recursive(g::EGraph{T}, n::VecExpr, get_node::Function) where {T}
  h = get_constant(g, v_head(n))
  v_istree(n) || return h
  children = map(c -> extract_expr_recursive(g, c, get_node), get_node.(v_children(n)))
  # TODO metadata?
  maketerm(T, h, children; is_call = v_isfuncall(n))
end


function (extractor::Extractor)(root = extractor.g.root)
  get_node(eclass_id::Id) = find_best_node(extractor, eclass_id)
  # TODO check if infinite cost?
  extract_expr_recursive(extractor.g, find_best_node(extractor, root), get_node)
end

# costs dict stores index of enode. get this enode from the eclass
function find_best_node(extractor::Extractor, eclass_id::Id)
  eclass = extractor.g[eclass_id]
  (_, node_index) = extractor.costs[eclass.id]
  eclass.nodes[node_index]
end

function find_costs!(extractor::Extractor{CF,CT}) where {CF,CT}
  function enode_cost(n::VecExpr)::CT
    if all(x -> haskey(extractor.costs, x), v_children(n))
      extractor.cost_function(
        n,
        get_constant(extractor.g, v_head(n)),
        map(child_id -> extractor.costs[child_id][1], v_children(n)),
      )
    else
      typemax(CT)
    end
  end


  did_something = true
  while did_something
    did_something = false

    for (id, eclass) in extractor.g.classes
      costs = enode_cost.(eclass.nodes)
      pass = (minimum(costs), argmin(costs))

      if pass != typemax(CT) && (!haskey(extractor.costs, id) || (pass[1] < extractor.costs[id][1]))
        extractor.costs[id] = pass
        did_something = true
      end
    end
  end

  for (id, _) in extractor.g.classes
    if !haskey(extractor.costs, id)
      error("failed to compute extraction costs for eclass ", id)
    end
  end
end

"""
A basic cost function, where the computed cost is the size
(number of children) of the current expression.
"""
function astsize(n::VecExpr, op, costs::Vector{Float64})::Float64
  v_istree(n) || return 1
  cost = 2 + v_arity(n)
  cost + sum(costs)
end

"""
A basic cost function, where the computed cost is the size
(number of children) of the current expression, times -1.
Strives to get the largest expression
"""
function astsize_inv(n::VecExpr, op, costs::Vector{Float64})::Float64
  v_istree(n) || return -1
  cost = -(1 + v_arity(n)) # minus sign here is the only difference vs astsize
  cost + sum(costs)
end


function extract!(g::EGraph, costfun)
  Extractor(g, costfun, Float64)()
end