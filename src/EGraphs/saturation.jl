mutable struct SaturationReport
  reason::Union{Symbol,Nothing}
  egraph::EGraph
  iterations::Int
  to::TimerOutput
end

SaturationReport() = SaturationReport(nothing, EGraph(), 0, TimerOutput())
SaturationReport(g::EGraph) = SaturationReport(nothing, g, 0, TimerOutput())

const Bindings = SubArray{UInt64,1,Vector{UInt64},Tuple{UnitRange{Int64}},true}

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
  eclasslimit::Int = 5000
  enodelimit::Int = 15000
  goal::Function = (g::EGraph) -> false
  scheduler::Type{<:AbstractScheduler} = BackoffScheduler
  schedulerparams::NamedTuple = (;)
  threaded::Bool = false
  timer::Bool = true
  "Activate check for memoization of nodes (hashcons) after rebuilding"
  check_memo::Bool = false
  "Activate check for join-semilattice invariant for semantic analysis values after rebuilding"
  check_analysis::Bool = false
end

function cached_ids(g::EGraph, p::PatExpr)::Vector{Id}
  if isground(p)
    id = lookup_pat(g, p)
    iszero(id) ? UNDEF_ID_VEC : [id]
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
  theory::Theory,
  scheduler::AbstractScheduler,
  report::SaturationReport,
  ematch_buffer::OptBuffer{UInt64},
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
      for i in ids_left
        cansearch(scheduler, rule_idx, i) || continue
        n_matches += rule.ematcher_left!(g, rule_idx, i, rule.stack, ematch_buffer)
        inform!(scheduler, rule_idx, i, n_matches)
      end

      if is_bidirectional(rule)
        ids_right = cached_ids(g, rule.right)
        for i in ids_right
          cansearch(scheduler, rule_idx, i) || continue
          n_matches += rule.ematcher_right!(g, rule_idx, i, rule.stack, ematch_buffer)
          inform!(scheduler, rule_idx, i, n_matches)
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

function instantiate_enode!(bindings::Bindings, isliteral_bitvec::UInt64, g::EGraph, p::PatLiteral)::Id
  add_constant_hashed!(g, p.value, v_head(p.n))
  add!(g, p.n, true)
end

function instantiate_enode!(bindings::Bindings, isliteral_bitvec::UInt64, g::EGraph, p::PatVar)::Id
  if v_bitvec_check(isliteral_bitvec, p.idx)
    add!(g, VecExpr(Id[0, 0, 0, bindings[p.idx]]), true)
  else
    bindings[p.idx]
  end
end

function instantiate_enode!(
  bindings::Bindings,
  isliteral_bitvec::UInt64,
  g::EGraph{ExpressionType},
  p::PatExpr,
)::Id where {ExpressionType}
  add_constant_hashed!(g, p.head, p.head_hash)

  for i in v_children_range(p.n)
    @inbounds p.n[i] = instantiate_enode!(bindings, isliteral_bitvec, g, p.children[i - VECEXPR_META_LENGTH])
  end
  add!(g, p.n, true)
end

function instantiate_enode!(bindings::Bindings, isliteral_bitvec::UInt64, g::EGraph{Expr}, p::PatExpr)::Id
  add_constant_hashed!(g, p.quoted_head, p.quoted_head_hash)
  v_set_head!(p.n, p.quoted_head_hash)

  for i in v_children_range(p.n)
    @inbounds p.n[i] = instantiate_enode!(bindings, isliteral_bitvec, g, p.children[i - VECEXPR_META_LENGTH])
  end
  add!(g, p.n, true)
end

"""
Instantiate argument for dynamic rule application in e-graph
"""
function instantiate_actual_param!(bindings::Bindings, isliteral_bitvec::UInt64, g::EGraph, i)
  val = bindings[i]
  if v_bitvec_check(isliteral_bitvec, i)
    get_constant(g, bindings[i])
  else
    val <= 0 && error("unbound pattern variable")
    g[val]
  end
end


struct RuleApplicationResult
  halt_reason::Symbol
  l::Id
  r::Id
end

function apply_rule!(
  bindings::Bindings,
  isliteral_bitvec::UInt64,
  g::EGraph,
  rule::RewriteRule,
  id::Id,
  direction::Int,
)::RuleApplicationResult
  # @show rule
  if rule.op === (-->) # DirectedRule
    new_id::Id = instantiate_enode!(bindings, isliteral_bitvec, g, rule.right)
    RuleApplicationResult(:nothing, new_id, id)
  elseif rule.op === (==) # EqualityRule
    pat_to_inst = direction == 1 ? rule.right : rule.left
    new_id = instantiate_enode!(bindings, isliteral_bitvec, g, pat_to_inst)
    RuleApplicationResult(:nothing, new_id, id)
  elseif rule.op === (!=) # UnequalRule
    pat_to_inst = direction == 1 ? rule.right : rule.left
    other_id = instantiate_enode!(bindings, isliteral_bitvec, g, pat_to_inst)

    if find(g, id) == find(g, other_id)
      @debug "$rule produced a contradiction!"
      return RuleApplicationResult(:contradiction, 0, 0)
    end
    RuleApplicationResult(:nothing, 0, 0)
  elseif rule.op === (|>) # DynamicRule
    r = rule.right(
      id,
      g,
      (instantiate_actual_param!(bindings, isliteral_bitvec, g, i) for i in 1:length(rule.patvars))...,
    )
    isnothing(r) && return RuleApplicationResult(:nothing, 0, 0)
    rcid = addexpr!(g, r)
    RuleApplicationResult(:nothing, rcid, id)
  else
    RuleApplicationResult(:error, 0, 0)
  end
end

const CHECK_GOAL_EVERY_N_MATCHES = 20

function eqsat_apply!(
  g::EGraph,
  theory::Theory,
  rep::SaturationReport,
  params::SaturationParams,
  ematch_buffer::OptBuffer{UInt64},
)
  n_matches = 0
  g.needslock && lock(g.lock)

  k = 1
  while k < length(ematch_buffer)
    if n_matches % CHECK_GOAL_EVERY_N_MATCHES == 0 && params.goal(g)
      @debug "Goal reached"
      rep.reason = :goalreached
      return
    end

    n_matches += 1


    id = ematch_buffer[k]
    rule_idx = reinterpret(Int, ematch_buffer[k + 1])
    isliteral_bitvec = ematch_buffer[k + 2]
    direction = sign(rule_idx)
    rule_idx = abs(rule_idx)
    rule = theory[rule_idx]

    bind_start = k + 3

    bind_end = bind_start + length(rule.patvars) - 1

    bindings = @view ematch_buffer[bind_start:bind_end]

    res = apply_rule!(bindings, isliteral_bitvec, g, rule, id, direction)

    k = bind_end + 1

    if res.halt_reason !== :nothing
      rep.reason = res.halt_reason
      return
    end

    if params.enodelimit > 0 && length(g.memo) > params.enodelimit
      @debug "Too many enodes"
      rep.reason = :enodelimit
      break
    end

    !iszero(res.l) && !iszero(res.r) && union!(g, res.l, res.r)
  end

  empty!(ematch_buffer)

  if params.goal(g)
    @debug "Goal reached"
    rep.reason = :goalreached
    return
  end

  g.needslock && unlock(g.lock)
end


"""
Core algorithm of the library: the equality saturation step.
"""
function eqsat_step!(
  g::EGraph,
  theory::Theory,
  curr_iter::Int,
  scheduler::AbstractScheduler,
  params::SaturationParams,
  report::SaturationReport,
  ematch_buffer::OptBuffer{UInt64},
)

  setiter!(scheduler, curr_iter)

  @timeit report.to "Search" eqsat_search!(g, theory, scheduler, report, ematch_buffer)

  @timeit report.to "Apply" eqsat_apply!(g, theory, report, params, ematch_buffer)
  if report.reason === nothing && cansaturate(scheduler) && isempty(g.pending)
    report.reason = :saturated
  end
  @timeit report.to "Rebuild" rebuild!(
    g;
    should_check_memo = params.check_memo,
    should_check_analysis = params.check_analysis,
  )

  Schedulers.rebuild!(scheduler)

  @debug "Smallest expression is" extract!(g, astsize)

  return report
end

"""
Given an [`EGraph`](@ref) and a collection of rewrite rules,
execute the equality saturation algorithm.
"""
function saturate!(g::EGraph, theory::Theory, params = SaturationParams())
  curr_iter = 0

  sched = params.scheduler(g, theory; params.schedulerparams...)
  report = SaturationReport(g)

  start_time = time_ns()

  params.timer || disable_timer!(report.to)

  # Buffer for e-matching. Use a local buffer for generated functions.
  ematch_buffer = OptBuffer{UInt64}(64)

  while true
    curr_iter += 1

    @debug "================ EQSAT ITERATION $curr_iter  ================"
    @debug g

    report = eqsat_step!(g, theory, curr_iter, sched, params, report, ematch_buffer)

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
