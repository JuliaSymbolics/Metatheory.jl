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
  println(io, "\tEGraph Size: $(length(g.classes)) eclasses, $(length(g.memo)) nodes")
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
  goal::Function                       = (g::EGraph) -> false
  scheduler::Type{<:AbstractScheduler} = BackoffScheduler
  schedulerparams::Tuple               = ()
  threaded::Bool                       = false
  timer::Bool                          = true
end

function cached_ids(g::EGraph, p::PatTerm)::Vector{Id}
  if isground(p)
    id = lookup_pat(g, p)
    !isnothing(id) && return [id]
  else
    get(g.classes_by_op, op_key(p), UNDEF_ID_VEC)
  end
end

function cached_ids(g::EGraph, p) # p is a literal
  id = lookup_pat(g, p)
  id > 0 && return [id]
  return []
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
    prev_matches = n_matches
    @timeit report.to string(rule_idx) begin
      prev_matches = n_matches
      # don't apply banned rules
      if !cansearch(scheduler, rule)
        @debug "$rule is banned"
        continue
      end
      ids = let left = cached_ids(g, rule.left)
        if rule isa BidirRule
          Iterators.flatten((left, cached_ids(g, rule.right)))
        else
          left
        end
      end

      @debug "Matching" rule ids

      for i in ids
        n_matches += rule.ematcher!(g, rule_idx, i)
      end
      n_matches - prev_matches > 0 && @debug "Rule $rule_idx: $rule produced $(n_matches - prev_matches) matches"
      inform!(scheduler, rule, n_matches)
    end
  end


  return n_matches
end

function instantiate_enode!(@nospecialize(g::EGraph), p::Any)::Id
  # TODO make op_key here and do not allocate if it's already there
  new_node_literal = Id[0, 0, add_constant!(g, p)]
  add!(g, new_node_literal)
end
instantiate_enode!(@nospecialize(g::EGraph), p::PatVar)::Id = v_pair_first(g.buffer[g.buffer_position + p.idx - 1])
function instantiate_enode!(g::EGraph{ExpressionType}, p::PatTerm)::Id where {ExpressionType}
  op = head(p)
  args = children(p)
  is_call = is_function_call(p)
  # TODO handle this situation better
  new_op = ExpressionType === Expr && op isa Union{Function,DataType} ? nameof(op) : op

  ar = arity(p)
  n = v_new(ar)
  v_set_flag!(n, VECEXPR_FLAG_ISTREE)
  is_call && v_set_flag!(n, VECEXPR_FLAG_ISCALL)
  v_set_head!(n, add_constant!(g, new_op))

  # TODO optimize if node is already there

  for i in v_children_range(n)
    @inbounds n[i] = instantiate_enode!(g, args[i - VECEXPR_META_LENGTH])
  end
  add!(g, n)
end

function apply_rule!(g::EGraph, rule::RewriteRule, id, direction)
  push!(g.merges_buffer, id)
  push!(g.merges_buffer, instantiate_enode!(g, rule.right))
  nothing
end

function apply_rule!(g::EGraph, rule::EqualityRule, id::Id, direction::Int)
  pat_to_inst = direction == 1 ? rule.right : rule.left
  push!(g.merges_buffer, id)
  push!(g.merges_buffer, instantiate_enode!(g, pat_to_inst))
  nothing
end


function apply_rule!(g::EGraph, rule::UnequalRule, id::Id, direction::Int)
  pat_to_inst = direction == 1 ? rule.right : rule.left
  other_id = instantiate_enode!(g, pat_to_inst)

  if find(g, id) == find(g, other_id)
    @debug "$rule produced a contradiction!"
    return :contradiction
  end
  nothing
end

"""
Instantiate argument for dynamic rule application in e-graph
"""
function instantiate_actual_param!(g::EGraph, i)
  p = g.buffer[g.buffer_position + i - 1]
  ecid = v_pair_first(p)
  literal_position = v_pair_last(p)

  ecid <= 0 && error("unbound pattern variable")
  eclass = g[ecid]
  if literal_position > 0
    @assert !v_istree(eclass[literal_position])
    return get_constant(g, v_head(eclass[literal_position]))
  end
  return eclass
end

function apply_rule!(g::EGraph, rule::DynamicRule, id::Id, direction::Int)
  f = rule.rhs_fun
  r = f(id, g, (instantiate_actual_param!(g, i) for i in 1:length(rule.patvars))...)
  isnothing(r) && return nothing
  rcid = addexpr!(g, r)
  push!(g.merges_buffer, id)
  push!(g.merges_buffer, rcid)
  return nothing
end



function eqsat_apply!(g::EGraph, theory::Vector{<:AbstractRule}, rep::SaturationReport, params::SaturationParams)
  @assert isempty(g.merges_buffer)

  @debug "APPLYING $(length(g.buffer)) matches"
  maybelock!(g) do
    while g.buffer_position <= length(g.buffer)

      if params.goal(g)
        @debug "Goal reached"
        rep.reason = :goalreached
        return
      end

      id = v_pair_first(g.buffer[g.buffer_position])
      rule_idx = reinterpret(Int, v_pair_last(g.buffer[g.buffer_position]))

      @debug "id" id
      @debug "rule idx" rule_idx
      direction = sign(rule_idx)
      rule_idx = abs(rule_idx)
      rule = theory[rule_idx]
      npvars = length(rule.patvars)

      @show g.buffer[(g.buffer_position):(g.buffer_position + npvars)]

      g.buffer_position += 1


      halt_reason = apply_rule!(g, rule, id, direction)

      g.buffer_position += npvars


      if !isnothing(halt_reason)
        rep.reason = halt_reason
        return
      end

      if params.enodelimit > 0 && length(g.memo) > params.enodelimit
        @debug "Too many enodes"
        rep.reason = :enodelimit
        break
      end
    end
  end
  maybelock!(g) do
    while !isempty(g.merges_buffer)
      l = pop!(g.merges_buffer)
      r = pop!(g.merges_buffer)
      union!(g, l, r)
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

  g.buffer_position = 1

  @timeit report.to "Search" eqsat_search!(g, theory, scheduler, report)

  g.buffer_position = 1

  @timeit report.to "Apply" eqsat_apply!(g, theory, report, params)

  if report.reason === nothing && cansaturate(scheduler) && isempty(g.pending)
    report.reason = :saturated
  end
  @timeit report.to "Rebuild" rebuild!(g)

  @debug "Smallest expression is" extract!(g, astsize)

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

  while true
    curr_iter += 1

    @debug "================ EQSAT ITERATION $curr_iter  ================"

    report = eqsat_step!(g, theory, curr_iter, sched, params, report)

    elapsed = time_ns() - start_time

    if params.goal(g)
      @debug "Goal reached"
      report.reason = :goalreached
      break
    end

    if report.reason !== nothing
      @debug "Reason" report.reason
      break
    end

    if params.timelimit > 0 && params.timelimit <= elapsed
      @debug "Time limit reached"
      report.reason = :timelimit
      break
    end

    if curr_iter >= params.timeout
      @debug "Too many iterations"
      report.reason = :timeout
      break
    end

    if params.eclasslimit > 0 && length(g.classes) > params.eclasslimit
      @debug "Too many eclasses"
      report.reason = :eclasslimit
      break
    end
  end
  report.iterations = curr_iter

  return report
end

function areequal(theory::Vector, exprs...; params = SaturationParams())
  g = EGraph(exprs[1])
  areequal(g, theory, exprs...; params)
end

function areequal(g::EGraph, t::Vector{<:AbstractRule}, exprs...; params = SaturationParams())
  n = length(exprs)
  n == 1 && return true

  ids = [addexpr!(g, ex) for ex in exprs]
  params = deepcopy(params)
  params.goal = (g::EGraph) -> in_same_class(g, ids...)

  report = saturate!(g, t, params)

  goal_reached = params.goal(g)

  if !(report.reason === :saturated) && !goal_reached
    return missing # failed to prove
  end
  return goal_reached
end

macro areequal(theory, exprs...)
  esc(:(areequal($theory, $exprs...)))
end

macro areequalg(G, theory, exprs...)
  esc(:(areequal($G, $theory, $exprs...)))
end
