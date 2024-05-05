struct Extractor{CostFun,Cost}
  g::EGraph
  cost_function::CostFun
  costs::Dict{IdKey,Tuple{Cost,Int64}} # Cost and index in eclass
  Extractor{CF,C}(g::EGraph, cf::CF, d::Dict{IdKey,Tuple{C,Int64}}) where {CF,C} = new{CF,C}(g, cf, d)
end

"""
Given a cost function, extract the expression
with the smallest computed cost from an [`EGraph`](@ref)
"""
function Extractor(g::EGraph, cost_function::Function, cost_type = Float64)
  extractor = Extractor{typeof(cost_function),cost_type}(g, cost_function, Dict{IdKey,Tuple{cost_type,Int64}}())
  find_costs!(extractor)
  extractor
end

function extract_expr_recursive(g::EGraph{T}, n::VecExpr, get_node::Function) where {T}
  h = get_constant(g, v_head(n))
  v_isexpr(n) || return h
  children = map(c -> extract_expr_recursive(g, c, get_node), get_node.(v_children(n)))
  # TODO metadata?
  maketerm(T, h, children)
end

extract_expr_recursive(g::EGraph{T}, h::Id, get_node::Function) where {T} = get_constant(g, h)

function extract_expr_recursive(g::EGraph{Expr}, n::VecExpr, get_node::Function)
  h = get_constant(g, v_head(n))
  v_isexpr(n) || return h
  children = map(c -> extract_expr_recursive(g, c, get_node), get_node.(v_children(n)))

  if v_iscall(n)
    maketerm(Expr, :call, [h; children])
  else
    maketerm(Expr, h, children)
  end
end


function (extractor::Extractor)(root = extractor.g.root)
  get_node(eclass_id::Id) = find_best_node(extractor, eclass_id)
  # TODO check if infinite cost?
  extract_expr_recursive(extractor.g, find_best_node(extractor, root), get_node)
end

# costs dict stores index of enode. get this enode from the eclass
function find_best_node(extractor::Extractor, eclass_id::Id)
  eclass = extractor.g[eclass_id]
  (_, node_index) = extractor.costs[IdKey(eclass.id)]
  nlit = length(eclass.literals)
  if node_index <= nlit
    return eclass.literals[node_index]
  end
  eclass.nodes[node_index - nlit]
end

function find_costs!(extractor::Extractor{CF,CT}) where {CF,CT}
  did_something = true
  while did_something
    did_something = false

    for (id, eclass) in extractor.g.classes
      min_cost = typemax(CT)
      min_cost_node_idx = 0

      nlit = length(eclass.literals)
      for (idx, h) in enumerate(eclass.literals)
        cost = extractor.cost_function(get_constant(extractor.g, h))
        if cost < min_cost
          min_cost = cost
          min_cost_node_idx = idx
        end
      end

      for (idx, n) in enumerate(eclass.nodes)
        has_all = true
        for child_id in v_children(n)
          has_all = has_all && haskey(extractor.costs, IdKey(child_id))
          has_all || break
        end
        if has_all
          cost = extractor.cost_function(
            n,
            get_constant(extractor.g, v_head(n)),
            map(child_id -> extractor.costs[IdKey(child_id)][1], v_children(n)),
          )
          if cost < min_cost
            min_cost = cost
            min_cost_node_idx = nlit + idx
          end
        end
      end

      if min_cost != typemax(CT) && (!haskey(extractor.costs, id) || (min_cost < extractor.costs[id][1]))
        extractor.costs[id] = (min_cost, min_cost_node_idx)
        did_something = true
      end
    end
  end

  for (id, _) in extractor.g.classes
    if !haskey(extractor.costs, id)
      error("failed to compute extraction costs for eclass ", id.val)
    end
  end
end

"""
A basic cost function, where the computed cost is the number 
of expression tree nodes.
"""
astsize(n::VecExpr, op, costs)::Float64 = cost = 1 + sum(costs)
astsize(x) = 1

"""
A basic cost function, where the computed cost is the number
of expression tree nodes times -1.
Strives to get the largest expression. This may lead to stack overflow for egraphs with loops.
"""
astsize_inv(n::VecExpr, op, costs::Vector{Float64})::Float64 = cost = -1 + sum(costs)
astsize_inv(x) = -1

function extract!(g::EGraph, costfun, root = g.root, cost_type = Float64)
  Extractor(g, costfun, cost_type)(root)
end

