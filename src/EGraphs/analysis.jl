analysis_reference(x::Symbol) = Val(x)
analysis_reference(x::Function) = x
analysis_reference(x) = error("$x is not a valid analysis reference")

"""
    islazy(::Val{analysis_name})

Return whether an analysis is lazy. A lazy analysis is computed only when
[`analyze!`](@ref) is called; a non-lazy analysis is updated as e-nodes are
inserted and e-classes are merged.

Extend `islazy(::Val{:name})` for a custom symbolic analysis. Cost functions
are lazy by default.
"""
islazy(::Val{analysis_name}) where {analysis_name} = false
islazy(analysis_name) = islazy(analysis_reference(analysis_name))

"""
    modify!(::Val{analysis_name}, g, id)

Optionally modify `g[id]` after an analysis value has been computed, typically
by adding an e-node. The method must be idempotent when the e-class has not
otherwise changed, or saturation can fail to converge.

Return `nothing` when no modification is needed.
"""
modify!(::Val{analysis_name}, g, id) where {analysis_name} = nothing
modify!(an, g, id) = modify!(analysis_reference(an), g, id)


"""
    join(::Val{analysis_name}, a, b)

Combine two analysis values into one value in the analysis domain. The method
is used when e-classes merge and when an e-class contains multiple e-nodes.
It should be associative and, when the analysis is a semilattice, commutative
and idempotent.
"""
join(analysis::Val{analysis_name}, a, b) where {analysis_name} =
  error("Analysis $analysis_name does not implement join")
join(an, a, b) = join(analysis_reference(an), a, b)

"""
    make(::Val{analysis_name}, g, n)

Return the analysis value contributed by e-node `n` in `g`. The value is then
combined with other values by [`join`](@ref).

# Example

```julia
Metatheory.EGraphs.make(::Val{:constant}, g, node) =
    node isa ENodeLiteral ? node.value : nothing
Metatheory.EGraphs.join(::Val{:constant}, a, b) = a == b ? a : nothing
```
"""
make(::Val{analysis_name}, g, n) where {analysis_name} = error("Analysis $analysis_name does not implement make")
make(an, g, n) = make(analysis_reference(an), g, n)

analyze!(g::EGraph, analysis_ref, id::EClassId) = analyze!(g, analysis_ref, reachable(g, id))
analyze!(g::EGraph, analysis_ref) = analyze!(g, analysis_ref, collect(keys(g.classes)))


"""
    analyze!(egraph, analysis_name, [ECLASS_IDS])

Run a bottom-up analysis over the e-graph. `analysis_ref` may be a symbol or a
function; `ids` optionally restricts the traversal to selected reachable
e-classes. The analysis uses [`make`](@ref) for each e-node and [`join`](@ref)
to combine values, then stores the result for [`getdata`](@ref).

# Arguments

- `egraph`: Graph to analyze in place.
- `analysis_ref`: Symbolic analysis name or cost function.
- `ids`: Optional vector of root e-class identifiers.
"""
function analyze!(g::EGraph, analysis_ref, ids::Vector{EClassId})
  addanalysis!(g, analysis_ref)
  ids = sort(ids)
  # @assert isempty(g.dirty)

  did_something = true
  while did_something
    did_something = false

    for id in ids
      eclass = g[id]
      id = eclass.id
      pass = mapreduce(x -> make(analysis_ref, g, x), (x, y) -> join(analysis_ref, x, y), eclass)

      if !isequal(pass, getdata(eclass, analysis_ref, missing))
        setdata!(eclass, analysis_ref, pass)
        did_something = true
        push!(g.dirty, id)
      end
    end
  end

  for id in ids
    eclass = g[id]
    id = eclass.id
    if !hasdata(eclass, analysis_ref)
      error("failed to compute analysis for eclass ", id)
    end
  end

  return true
end

"""
    astsize(enode, egraph) -> Int

Return a cost equal to one plus the number of child e-nodes, plus the cost of
each child. This is the default small-expression extraction heuristic.
"""
function astsize(n::ENodeTerm, g::EGraph)
  cost = 1 + arity(n)
  for id in arguments(n)
    eclass = g[id]
    !hasdata(eclass, astsize) && (cost += Inf; break)
    cost += last(getdata(eclass, astsize))
  end
  return cost
end

astsize(n::ENodeLiteral, g::EGraph) = 1

"""
    astsize_inv(enode, egraph) -> Int

Return the negative of [`astsize`](@ref), causing extraction to prefer larger
expressions instead of smaller ones.
"""
function astsize_inv(n::ENodeTerm, g::EGraph)
  cost = -(1 + arity(n)) # minus sign here is the only difference vs astsize
  for id in arguments(n)
    eclass = g[id]
    !hasdata(eclass, astsize_inv) && (cost += Inf; break)
    cost += last(getdata(eclass, astsize_inv))
  end
  return cost
end

astsize_inv(n::ENodeLiteral, g::EGraph) = -1


"""
    make(costfun, egraph, enode)

Adapt a cost function to the analysis interface. The returned pair contains
the original e-node and its numeric cost.
"""
make(f::Function, g::EGraph, n::AbstractENode) = (n, f(n, g))

join(f::Function, from, to) = last(from) <= last(to) ? from : to

islazy(::Function) = true
modify!(::Function, g, id) = nothing

function rec_extract(g::EGraph, costfun, id::EClassId; cse_env = nothing)
  eclass = g[id]
  if !isnothing(cse_env) && haskey(cse_env, id)
    (sym, _) = cse_env[id]
    return sym
  end
  (n, ck) = getdata(eclass, costfun, (nothing, Inf))
  ck == Inf && error("Infinite cost when extracting enode")

  if n isa ENodeLiteral
    return n.value
  elseif n isa ENodeTerm
    children = map(arg -> rec_extract(g, costfun, arg; cse_env = cse_env), n.args)
    meta = getdata(eclass, :metadata_analysis, nothing)
    T = symtype(n)
    egraph_reconstruct_expression(T, operation(n), collect(children); metadata = meta, exprhead = exprhead(n))
  else
    error("Unknown ENode Type $(typeof(n))")
  end
end

"""
    extract!(egraph, costfun; root=-1, cse=false)

Extract the expression with the smallest `costfun` value from `egraph`.

# Arguments

- `egraph`: Graph to analyze and extract from.
- `costfun`: Function of `(enode, egraph)` returning a numeric cost.

# Keyword Arguments

- `root::EClassId=-1`: Root e-class; `-1` uses `egraph.root`.
- `cse::Bool=false`: Return a `let` expression that names repeated
  subexpressions when `true`.
"""
function extract!(g::EGraph, costfun::Function; root = -1, cse = false)
  if root == -1
    root = g.root
  end
  analyze!(g, costfun, root)
  if cse
    # TODO make sure there is no assignments/stateful code!!
    cse_env = OrderedDict{EClassId,Tuple{Symbol,Any}}() # 
    collect_cse!(g, costfun, root, cse_env, Set{EClassId}())

    body = rec_extract(g, costfun, root; cse_env = cse_env)

    assignments = [Expr(:(=), name, val) for (id, (name, val)) in cse_env]
    # return body
    Expr(:let, Expr(:block, assignments...), body)
  else
    return rec_extract(g, costfun, root)
  end
end


# Builds a dict e-class id => (symbol, extracted term) of common subexpressions in an e-graph
function collect_cse!(g::EGraph, costfun, id, cse_env, seen)
  eclass = g[id]
  (cn, ck) = getdata(eclass, costfun, (nothing, Inf))
  ck == Inf && error("Error when computing CSE")
  if cn isa ENodeTerm
    if id in seen
      cse_env[id] = (gensym(), rec_extract(g, costfun, id))#, cse_env=cse_env)) # todo generalize symbol?
      return
    end
    for child_id in arguments(cn)
      collect_cse!(g, costfun, child_id, cse_env, seen)
    end
    push!(seen, id)
  end
end


"""
    getcost!(g, costfun; root=-1)

Compute and return the minimum cost of the root e-class according to
`costfun`.

# Arguments

- `g`: E-graph to analyze.
- `costfun`: Function receiving `(enode, g)` and returning a numeric cost.

# Keyword Arguments

- `root::EClassId=-1`: Root e-class; `-1` uses `g.root`.

The analysis data in `g` is updated in place.
"""
function getcost!(g::EGraph, costfun; root = -1)
  if root == -1
    root = g.root
  end
  analyze!(g, costfun, root)
  bestnode, cost = getdata(g[root], costfun)
  return cost
end
