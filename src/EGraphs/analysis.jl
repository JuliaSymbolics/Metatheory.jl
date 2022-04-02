analysis_reference(x::Symbol) = Val(x)
analysis_reference(x::Function) = x
analysis_reference(x) = error("$x is not a valid analysis reference")

"""
    islazy(::Val{analysis_name})

Should return `true` if the EGraph Analysis `an` is lazy
and false otherwise. A *lazy* EGraph Analysis is computed 
only when [analyze!](@ref) is called. *Non-lazy* 
analyses are instead computed on-the-fly every time ENodes are added to the EGraph or
EClasses are merged.  
"""
islazy(::Val{analysis_name}) where {analysis_name} = false
islazy(analysis_name) = islazy(Val(analysis_name))

"""
    modify!(::Val{analysis_name}, g, id)

The `modify!` function for EGraph Analysis can optionally modify the eclass
`g[id]` after it has been analyzed, typically by adding an ENode.
It should be **idempotent** if no other changes occur to the EClass. 
(See the [egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304)).
"""
modify!(::Val{analysis_name}, g, id) where {analysis_name} = nothing
modify!(an, g, id) = modify!(analysis_reference(an), g, id)


"""
    join(::Val{analysis_name}, a, b)

Joins two analyses values into a single one, used by [analyze!](@ref)
when two eclasses are being merged or the analysis is being constructed.
"""
join(analysis::Val{analysis_name}, a, b) where {analysis_name} =
  error("Analysis $analysis_name does not implement join")
join(an, a, b) = join(analysis_reference(an), a, b)

"""
    make(::Val{analysis_name}, g, n)

Given an ENode `n`, `make` should return the corresponding analysis value. 
"""
make(::Val{analysis_name}, g, n) where {analysis_name} = error("Analysis $analysis_name does not implement make")
make(an, g, n) = make(analysis_reference(an), g, n)

analyze!(g::EGraph, analysis_ref, id::EClassId) = analyze!(g, analysis_ref, reachable(g, id))
analyze!(g::EGraph, analysis_ref) = analyze!(g, analysis_ref, collect(keys(g.classes)))


"""
    analyze!(egraph, analysis_name, [ECLASS_IDS])

Given an [EGraph](@ref) and an `analysis` identified by name `analysis_name`, 
do an automated bottom up trasversal of the EGraph, associating a value from the 
domain of analysis to each ENode in the egraph by the [make](@ref) function. 
Then, for each [EClass](@ref), compute the [join](@ref) of the children ENodes analyses values.
After `analyze!` is called, an analysis value will be associated to each EClass in the EGraph.
One can inspect and retrieve analysis values by using [hasdata](@ref) and [getdata](@ref).
"""
function analyze!(g::EGraph, analysis_ref, ids::Vector{EClassId})
  push!(g.analyses, analysis_ref)
  ids = sort(ids)
  # @assert isempty(g.dirty)

  did_something = true
  while did_something
    did_something = false

    for id in ids
      eclass = g[id]
      id = eclass.id
      pass = mapreduce(x -> make(analysis_ref, g, x), (x, y) -> join(analysis_ref, x, y), eclass)
      # pass = make_pass(G, analysis, find(G,id))

      # if pass !== missing
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
A basic cost function, where the computed cost is the size
(number of children) of the current expression.
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
A basic cost function, where the computed cost is the size
(number of children) of the current expression, times -1.
Strives to get the largest expression
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
When passing a function to analysis functions it is considered as a cost function
"""
make(f::Function, g::EGraph, n::AbstractENode) = (n, f(n, g))

join(f::Function, from, to) = last(from) <= last(to) ? from : to

islazy(::Function) = true

function rec_extract(g::EGraph, costfun, id::EClassId; cse_env = nothing)
  eclass = g[id]
  if !isnothing(cse_env) && haskey(cse_env, id)
    (sym, _) = cse_env[id]
    return sym
  end
  anval = getdata(eclass, costfun, (nothing, Inf))
  (n, ck) = anval
  ck == Inf && error("Infinite cost when extracting enode")

  if n isa ENodeLiteral
    return n.value
  elseif n isa ENodeTerm
    children = map(child -> rec_extract(g, costfun, child; cse_env = cse_env), arguments(n))
    meta = getdata(eclass, :metadata_analysis, nothing)
    T = termtype(n)
    egraph_reconstruct_expression(T, operation(n), children; metadata = meta, exprhead = exprhead(n))
  else
    error("Unknown ENode Type $(typeof(cn))")
  end
end

"""
Given a cost function, extract the expression
with the smallest computed cost from an [`EGraph`](@ref)
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
    # @show root
    # @show cse_env

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
  anval = getdata(eclass, costfun, (nothing, Inf))
  (cn, ck) = anval
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


function getcost!(g::EGraph, costfun; root = -1) where {F}
  if root == -1
    root = g.root
  end
  analyze!(g, costfun, root)
  bestnode, cost = getdata(g[root], costfun)
  return cost
end
