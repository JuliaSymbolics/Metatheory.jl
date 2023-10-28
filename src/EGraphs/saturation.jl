abstract type SaturationGoal end

reached(g::EGraph, goal::Nothing) = false
reached(g::EGraph, goal::SaturationGoal) = false

"""
This goal is reached when the `exprs` list of expressions are in the 
same equivalence class.
"""
struct EqualityGoal <: SaturationGoal
  exprs::Vector{Any}
  ids::Vector{EClassId}
  function EqualityGoal(exprs, eclasses)
    @assert length(exprs) == length(eclasses) && length(exprs) != 0
    new(exprs, eclasses)
  end
end

function reached(g::EGraph, goal::EqualityGoal)
  all(x -> in_same_class(g, goal.ids[1], x), @view goal.ids[2:end])
end

"""
Boolean valued function as an arbitrary saturation goal.
User supplied function must take an [`EGraph`](@ref) as the only parameter.
"""
struct FunctionGoal <: SaturationGoal
  fun::Function
end

function reached(g::EGraph, goal::FunctionGoal)::Bool
  goal.fun(g)
end

mutable struct SaturationReport
  reason::Union{Symbol,Nothing}
  egraph::EGraph
  iterations::Int
  to::TimerOutput
end

SaturationReport() = SaturationReport(nothing, EGraph(), 0, TimerOutput())
SaturationReport(g::EGraph) = SaturationReport(nothing, g, 0, TimerOutput())



# string representation of timedata
function Base.show(io::IO, x::SaturationReport)
  g = x.egraph
  println(io, "SaturationReport")
  println(io, "=================")
  println(io, "\tStop Reason: $(x.reason)")
  println(io, "\tIterations: $(x.iterations)")
  println(io, "\tEGraph Size: $(g.numclasses) eclasses, $(length(g.memo)) nodes")
  print_timer(io, x.to)
end

"""
Configurable Parameters for the equality saturation process.
"""
Base.@kwdef mutable struct SaturationParams
  timeout::Int = 8
  "Timeout in nanoseconds"
  timelimit::UInt64 = 0
  "Maximum number of eclasses allowed"
  eclasslimit::Int                     = 5000
  enodelimit::Int                      = 15000
  goal::Union{Nothing,SaturationGoal}  = nothing
  stopwhen::Function                   = () -> false
  scheduler::Type{<:AbstractScheduler} = BackoffScheduler
  schedulerparams::Tuple               = ()
  threaded::Bool                       = false
  timer::Bool                          = true
end

# function cached_ids(g::EGraph, p::PatTerm)# ::Vector{Int64}
#   if isground(p)
#     id = lookup_pat(g, p)
#     !isnothing(id) && return [id]
#   else
#     return keys(g.classes)
#   end
#   return []
# end

function cached_ids(g::EGraph, p::AbstractPattern) # p is a literal
  @warn "Pattern matching against the whole e-graph"
  return keys(g.classes)
end

function cached_ids(g::EGraph, p) # p is a literal
  id = lookup(g, ENodeLiteral(p))
  id > 0 && return [id]
  return []
end


# function cached_ids(g::EGraph, p::PatTerm)
#   arr = get(g.symcache, operation(p), EClassId[])
#   if operation(p) isa Union{Function,DataType}
#     append!(arr, get(g.symcache, nameof(operation(p)), EClassId[]))
#   end
#   arr
# end

function cached_ids(g::EGraph, p::PatTerm)
  keys(g.classes)
end


"""
Returns an iterator of `Match`es.
"""
function eqsat_search!(
  g::EGraph,
  theory::Vector{<:AbstractRule},
  scheduler::AbstractScheduler,
  report::SaturationReport,
)::Int
  n_matches = 0

  maybelock!(g) do
    empty!(g.buffer)
  end

  @debug "SEARCHING"
  for (rule_idx, rule) in enumerate(theory)
    @timeit report.to string(rule_idx) begin
      # don't apply banned rules
      if !cansearch(scheduler, rule)
        @debug "$rule is banned"
        continue
      end
      ids = cached_ids(g, rule.left)
      rule isa BidirRule && (ids = ids ∪ cached_ids(g, rule.right))
      for i in ids
        n_matches += rule.ematcher!(g, rule_idx, i)
      end
      n_matches > 0 && @debug "Rule $rule_idx: $rule produced $n_matches matches"
      inform!(scheduler, rule, n_matches)
    end
  end


  return n_matches
end


function drop_n!(D::CircularDeque, nn)
  D.n -= nn
  tmp = D.first + nn
  D.first = tmp > D.capacity ? 1 : tmp
end

instantiate_enode!(bindings::Bindings, g::EGraph, p::Any)::EClassId = add!(g, ENodeLiteral(p))
instantiate_enode!(bindings::Bindings, g::EGraph, p::PatVar)::EClassId = bindings[p.idx][1]
function instantiate_enode!(bindings::Bindings, g::EGraph, p::PatTerm)::EClassId
  eh = exprhead(p)
  op = operation(p)
  ar = arity(p)
  args = arguments(p)
  T = gettermtype(g, op, ar)
  # TODO add predicate check `quotes_operation`
  new_op = T == Expr && op isa Union{Function,DataType} ? nameof(op) : op
  add!(g, ENodeTerm(eh, new_op, T, map(arg -> instantiate_enode!(bindings, g, arg), args)))
end

function apply_rule!(buf, g::EGraph, rule::RewriteRule, id, direction)
  push!(g.merges_buffer, (id, instantiate_enode!(buf, g, rule.right)))
  nothing
end

function apply_rule!(bindings::Bindings, g::EGraph, rule::EqualityRule, id::EClassId, direction::Int)
  pat_to_inst = direction == 1 ? rule.right : rule.left
  push!(g.merges_buffer, (id, instantiate_enode!(bindings, g, pat_to_inst)))
  nothing
end


function apply_rule!(bindings::Bindings, g::EGraph, rule::UnequalRule, id::EClassId, direction::Int)
  pat_to_inst = direction == 1 ? rule.right : rule.left
  other_id = instantiate_enode!(bindings, g, pat_to_inst)

  if find(g, id) == find(g, other_id)
    @debug "$rule produced a contradiction!"
    return :contradiction
  end
  nothing
end

"""
Instantiate argument for dynamic rule application in e-graph
"""
function instantiate_actual_param!(bindings::Bindings, g::EGraph, i)
  ecid, literal_position = bindings[i]
  ecid <= 0 && error("unbound pattern variable")
  eclass = g[ecid]
  if literal_position > 0
    @assert eclass[literal_position] isa ENodeLiteral
    return eclass[literal_position].value
  end
  return eclass
end

function apply_rule!(bindings::Bindings, g::EGraph, rule::DynamicRule, id::EClassId, direction::Int)
  f = rule.rhs_fun
  r = f(id, g, (instantiate_actual_param!(bindings, g, i) for i in 1:length(rule.patvars))...)
  isnothing(r) && return nothing
  rcid = addexpr!(g, r)
  push!(g.merges_buffer, (id, rcid))
  return nothing
end



function eqsat_apply!(g::EGraph, theory::Vector{<:AbstractRule}, rep::SaturationReport, params::SaturationParams)
  i = 0
  @assert isempty(g.merges_buffer)

  @debug "APPLYING $(length(g.buffer)) matches"
  maybelock!(g) do
    while !isempty(g.buffer)

      if reached(g, params.goal)
        @debug "Goal reached"
        rep.reason = :goalreached
        return
      end

      bindings = pop!(g.buffer)
      rule_idx, id = bindings[0]
      direction = sign(rule_idx)
      rule_idx = abs(rule_idx)
      rule = theory[rule_idx]


      halt_reason = apply_rule!(bindings, g, rule, id, direction)

      if !isnothing(halt_reason)
        rep.reason = halt_reason
        return
      end
    end
  end
  maybelock!(g) do
    while !isempty(g.merges_buffer)
      (l, r) = pop!(g.merges_buffer)
      merge!(g, l, r)
    end
  end
end


"""
Core algorithm of the library: the equality saturation step.
"""
function eqsat_step!(
  g::EGraph,
  theory::Vector{<:AbstractRule},
  curr_iter,
  scheduler::AbstractScheduler,
  params::SaturationParams,
  report,
)

  setiter!(scheduler, curr_iter)

  @timeit report.to "Search" eqsat_search!(g, theory, scheduler, report)

  @timeit report.to "Apply" eqsat_apply!(g, theory, report, params)

  if report.reason === nothing && cansaturate(scheduler) && isempty(g.dirty)
    report.reason = :saturated
  end
  @timeit report.to "Rebuild" rebuild!(g)

  @debug smallest_expr = extract!(g, astsize)

  return report
end

"""
Given an [`EGraph`](@ref) and a collection of rewrite rules,
execute the equality saturation algorithm.
"""
function saturate!(g::EGraph, theory::Vector{<:AbstractRule}, params = SaturationParams())
  curr_iter = 0

  sched = params.scheduler(g, theory, params.schedulerparams...)
  report = SaturationReport(g)

  start_time = time_ns()

  !params.timer && disable_timer!(report.to)
  timelimit = params.timelimit > 0

  while true
    curr_iter += 1

    @debug "================ EQSAT ITERATION $curr_iter  ================"

    report = eqsat_step!(g, theory, curr_iter, sched, params, report)

    elapsed = time_ns() - start_time

    if timelimit && params.timelimit <= elapsed
      report.reason = :timelimit
      break
    end

    if !(report.reason isa Nothing)
      break
    end

    if curr_iter >= params.timeout
      report.reason = :timeout
      break
    end

    if params.eclasslimit > 0 && g.numclasses > params.eclasslimit
      report.reason = :eclasslimit
      break
    end

    if reached(g, params.goal)
      report.reason = :goalreached
      break
    end
  end
  report.iterations = curr_iter

  return report
end

function areequal(theory::Vector, exprs...; params = SaturationParams())
  g = EGraph(exprs[1])
  areequal(g, theory, exprs...; params = params)
end

function areequal(g::EGraph, t::Vector{<:AbstractRule}, exprs...; params = SaturationParams())
  if length(exprs) == 1
    return true
  end

  n = length(exprs)
  ids = map(Base.Fix1(addexpr!, g), collect(exprs))
  goal = EqualityGoal(collect(exprs), ids)

  params.goal = goal

  report = saturate!(g, t, params)

  if !(report.reason === :saturated) && !reached(g, goal)
    return missing # failed to prove
  end
  return reached(g, goal)
end

macro areequal(theory, exprs...)
  esc(:(areequal($theory, $exprs...)))
end

macro areequalg(G, theory, exprs...)
  esc(:(areequal($G, $theory, $exprs...)))
end
