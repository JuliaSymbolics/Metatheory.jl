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

function cached_ids(g::EGraph, p::PatExpr)::Vector{Id}
  if isground(p)
    id = lookup_pat(g, p)
    !isnothing(id) && return [id]
  else
    get(g.classes_by_op, IdKey(v_signature(p.n)), UNDEF_ID_VEC)
  end
end

function cached_ids(g::EGraph, p::PatLiteral) # p is a literal
  id = lookup_pat(g, p)
  id > 0 && return [id]
  return UNDEF_ID_VEC
end

cached_ids(g::EGraph, p::PatVar) = Iterators.map(x -> x.val, keys(g.classes))

"""
Returns an iterator of `Match`es.
"""
function eqsat_search!(
  g::EGraph,
  theory::Vector{NewRewriteRule},
  scheduler::AbstractScheduler,
  report::SaturationReport,
  ematch_buffer::OptBuffer{UInt128},
)::Int
  n_matches = 0

  g.needslock && lock(g.lock)
  empty!(ematch_buffer)
  g.needslock && unlock(g.lock)


  @debug "SEARCHING"
  for (rule_idx, rule) in enumerate(theory)
    prev_matches = n_matches
    @timeit report.to string(rule_idx) begin
      prev_matches = n_matches
      # don't apply banned rules
      if !cansearch(scheduler, rule_idx)
        @debug "$rule is banned"
        continue
      end
      ids_left = cached_ids(g, rule.left)
      ids_right = is_bidirectional(rule) ? cached_ids(g, rule.right) : UNDEF_ID_VEC


      for i in ids_left
        n_matches += rule.ematcher_left!(g, rule_idx, i, rule.stack, ematch_buffer)
      end

      if is_bidirectional(rule)
        @show rule
        for i in ids_right
          n_matches += rule.ematcher_right!(g, rule_idx, i, rule.stack, ematch_buffer)
        end
      end

      n_matches - prev_matches > 0 && @debug "Rule $rule_idx: $rule produced $(n_matches - prev_matches) matches"
      # if n_matches - prev_matches > 2 && rule_idx == 2
      #   @debug buffer_readable(g, old_len)
      # end
      inform!(scheduler, rule_idx, n_matches)
    end
  end


  return n_matches
end

function instantiate_enode!(bindings, @nospecialize(g::EGraph), p::PatLiteral)::Id
  add_constant!(g, p.value)
  add!(g, p.n, true)
end

instantiate_enode!(bindings, @nospecialize(g::EGraph), p::PatVar)::Id = v_pair_first(bindings[p.idx])
function instantiate_enode!(bindings, g::EGraph{ExpressionType}, p::PatExpr)::Id where {ExpressionType}
  add_constant_hashed!(g, p.head, p.head_hash)

  for i in v_children_range(p.n)
    @inbounds p.n[i] = instantiate_enode!(bindings, g, p.children[i - VECEXPR_META_LENGTH])
  end
  add!(g, p.n, true)
end

function instantiate_enode!(bindings, g::EGraph{Expr}, p::PatExpr)::Id
  add_constant_hashed!(g, p.quoted_head, p.quoted_head_hash)
  v_set_head!(p.n, p.quoted_head_hash)

  for i in v_children_range(p.n)
    @inbounds p.n[i] = instantiate_enode!(bindings, g, p.children[i - VECEXPR_META_LENGTH])
  end
  add!(g, p.n, true)
end

function apply_rule!(buf, g::EGraph, rule::DirectedRule, id, direction, merges_buffer::OptBuffer{UInt128})
  new_id::Id = instantiate_enode!(buf, g, rule.right)
  push!(merges_buffer, v_pair(new_id, id))
  nothing
end

function apply_rule!(bindings, g::EGraph, rule::EqualityRule, id::Id, direction::Int, merges_buffer::OptBuffer{UInt128})
  pat_to_inst = direction == 1 ? rule.right : rule.left
  new_id = instantiate_enode!(bindings, g, pat_to_inst)
  push!(merges_buffer, v_pair(new_id, id))
  nothing
end


function apply_rule!(bindings, g::EGraph, rule::UnequalRule, id::Id, direction::Int, ::OptBuffer{UInt128})
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
function instantiate_actual_param!(bindings, g::EGraph, i)
  ecid = v_pair_first(bindings[i])
  literal_position = reinterpret(Int, v_pair_last(bindings[i]))
  ecid <= 0 && error("unbound pattern variable")
  eclass = g[ecid]
  if literal_position > 0
    @assert !v_isexpr(eclass[literal_position])
    return get_constant(g, v_head(eclass[literal_position]))
  end
  return eclass
end

function apply_rule!(bindings, g::EGraph, rule::DynamicRule, id::Id, direction::Int, merges_buffer::OptBuffer{UInt128})
  r = rule.right(id, g, (instantiate_actual_param!(bindings, g, i) for i in 1:length(rule.patvars))...)
  isnothing(r) && return nothing
  rcid = addexpr!(g, r)
  push!(merges_buffer, v_pair(rcid, id))
  return nothing
end

const CHECK_GOAL_EVERY_N_MATCHES = 20

function eqsat_apply!(
  g::EGraph,
  theory::Vector{NewRewriteRule},
  rep::SaturationReport,
  params::SaturationParams,
  ematch_buffer::OptBuffer{UInt128},
  merges_buffer::OptBuffer{UInt128},
)
  @assert isempty(merges_buffer)

  n_matches = 0
  k = length(ematch_buffer)

  @debug "APPLYING $(count((==)(0xffffffffffffffffffffffffffffffff), ematch_buffer)) matches"
  g.needslock && lock(g.lock)
  while k > 0

    if n_matches % CHECK_GOAL_EVERY_N_MATCHES == 0 && params.goal(g)
      @debug "Goal reached"
      rep.reason = :goalreached
      return
    end

    delimiter = ematch_buffer.v[k]
    @assert delimiter == 0xffffffffffffffffffffffffffffffff
    n = k - 1

    next_delimiter_idx = 0
    n_elems = 0
    for i in n:-1:1
      n_elems += 1
      if ematch_buffer.v[i] == 0xffffffffffffffffffffffffffffffff
        n_elems -= 1
        next_delimiter_idx = i
        break
      end
    end

    n_matches += 1
    match_info = ematch_buffer.v[next_delimiter_idx + 1]
    id = v_pair_first(match_info)
    rule_idx = reinterpret(Int, v_pair_last(match_info))
    direction = sign(rule_idx)
    rule_idx = abs(rule_idx)
    rule = theory[rule_idx]

    bindings = @view ematch_buffer.v[(next_delimiter_idx + 2):n]

    halt_reason = apply_rule!(bindings, g, rule, id, direction, merges_buffer)

    k = next_delimiter_idx
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
  if params.goal(g)
    @debug "Goal reached"
    rep.reason = :goalreached
    return
  end

  empty!(ematch_buffer)

  g.needslock && unlock(g.lock)

  g.needslock && lock(g.lock)
  while !isempty(merges_buffer)
    p = pop!(merges_buffer)
    l = v_pair_first(p)
    r = v_pair_last(p)
    union!(g, l, r)
  end
  g.needslock && unlock(g.lock)
end


"""
Core algorithm of the library: the equality saturation step.
"""
function eqsat_step!(
  g::EGraph,
  theory::Vector{NewRewriteRule},
  curr_iter,
  scheduler::AbstractScheduler,
  params::SaturationParams,
  report,
  ematch_buffer::OptBuffer{UInt128},
  merges_buffer::OptBuffer{UInt128},
)

  setiter!(scheduler, curr_iter)

  @timeit report.to "Search" eqsat_search!(g, theory, scheduler, report, ematch_buffer)

  @timeit report.to "Apply" eqsat_apply!(g, theory, report, params, ematch_buffer, merges_buffer)

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
function saturate!(g::EGraph, theory::Vector{NewRewriteRule}, params = SaturationParams())
  curr_iter = 0

  sched = params.scheduler(g, theory, params.schedulerparams...)
  report = SaturationReport(g)

  start_time = time_ns()

  params.timer || disable_timer!(report.to)

  # Buffer for e-matching. Use a local buffer for generated functions.
  ematch_buffer = OptBuffer{UInt128}(64)
  # Buffer for rule application. Use a local buffer for generated functions.
  merges_buffer = OptBuffer{UInt128}(64)

  while true
    curr_iter += 1

    @debug "================ EQSAT ITERATION $curr_iter  ================"
    @debug g

    report = eqsat_step!(g, theory, curr_iter, sched, params, report, ematch_buffer, merges_buffer)

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

function areequal(g::EGraph, t::Vector{NewRewriteRule}, exprs...; params = SaturationParams())
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
