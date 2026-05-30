mutable struct SaturationReport
  reason::Union{Symbol,Nothing}
  egraph::EGraph
  iterations::Int
  to::TimerOutput
end

SaturationReport() = SaturationReport(nothing, EGraph(), 0, TimerOutput())
SaturationReport(g::EGraph) = SaturationReport(nothing, g, 0, TimerOutput())

const Bindings = SubArray{UInt64,1,Memory{UInt64},Tuple{UnitRange{Int64}},true}

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

function cached_ids(g::EGraph, p::Pat)
  p.type === PAT_VARIABLE && return sorted_class_ids(g)

  if p.isground
    id = lookup_pat(g, p)
    id > 0 ? [id] : UNDEF_ID_VEC
  elseif p.has_segment_children
    # EXPENSIVE: O(eclasses × nodes) scan — segment patterns match any arity so
    # the arity-indexed classes_by_op cache cannot be used.
    head_h  = v_head(p.n)
    name_h  = p.name_hash
    flags_p = v_flags(p.n)
    ids = Id[]
    for class_id in sorted_class_ids(g)
      eclass = g.classes[IdKey(class_id)]
      for n in eclass.nodes
        if v_flags(n) == flags_p && (v_head(n) == head_h || v_head(n) == name_h)
          push!(ids, class_id)
          break
        end
      end
    end
    ids
  else
    get(g.classes_by_op, IdKey(v_signature(p.n)), UNDEF_ID_VEC)
  end
end

"""
Returns the number of matches
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

  # Pre-compute timer label strings once (avoid String allocation inside the hot loop).
  rule_labels = [string(i) for i in 1:length(theory)]

  @debug "SEARCHING"
  for (rule_idx, rule) in enumerate(theory)
    @timeit report.to rule_labels[rule_idx] begin
      rule_n_matches = search_matches!(scheduler, ematch_buffer, rule_idx)
    end
    rule_n_matches > 0 && @debug "Rule $rule_idx: $rule produced $(rule_n_matches) matches"
    n_matches += rule_n_matches
  end

  n_matches # this currently not used anywhere
end


function instantiate_enode!(bindings::Bindings, isliteral_bitvec::UInt64, g::EGraph, p::Pat, seg_buf::OptBuffer{UInt64} = OptBuffer{UInt64}(0))::Id
  if p.type === PAT_VARIABLE
    return if v_bitvec_check(isliteral_bitvec, p.idx)
      add!(g, v_new_literal(bindings[p.idx]), true)
    else
      bindings[p.idx]
    end
  elseif p.type === PAT_LITERAL
    add_constant_hashed!(g, p.head, p.head_hash)
  elseif p.type === PAT_EXPR
    if p.has_segment_children
      # Variable-arity instantiation: compute total child count from segment bindings.
      # EXPENSIVE: allocates a fresh VecExpr each call (cannot reuse p.n in-place).
      total_arity = 0
      for child in p.children
        if child.type === PAT_SEGMENT
          O = Int(bindings[child.idx])       # offset into seg_buf
          total_arity += Int(seg_buf[O + 1]) # seg_len stored at O+1 (1-indexed)
        else
          total_arity += 1
        end
      end

      fresh_n = v_new(total_arity)
      fresh_n.data[2] = p.n.data[2]  # copy flags (istree, iscall)

      if needs_operation_quoting(g)
        add_constant_hashed!(g, p.name, p.name_hash)
        fresh_n.data[4] = p.name_hash
      else
        add_constant_hashed!(g, p.head, p.head_hash)
        fresh_n.data[4] = p.head_hash
      end
      # Signature encodes (quoted_op, actual_arity) — must use runtime total_arity
      fresh_n.data[3] = hash(p.name, hash(total_arity))

      # Fill children: splat segments, insert scalar children directly
      ci = VECEXPR_META_LENGTH + 1
      for child in p.children
        if child.type === PAT_SEGMENT
          O   = Int(bindings[child.idx])
          L   = Int(seg_buf[O + 1])
          for j in 1:L
            fresh_n.data[ci] = seg_buf[O + 1 + j]
            ci += 1
          end
        else
          fresh_n.data[ci] = instantiate_enode!(bindings, isliteral_bitvec, g, child, seg_buf)
          ci += 1
        end
      end

      return add!(g, fresh_n, false)
    end

    # --- Fast path: no segment children (zero extra allocations) ---
    add_constant_hashed!(g, p.head, p.head_hash)

    if needs_operation_quoting(g)
      add_constant_hashed!(g, p.name, p.name_hash)
      v_set_head!(p.n, p.name_hash)
    end

    for i in v_children_range(p.n)
      @inbounds p.n[i] = instantiate_enode!(bindings, isliteral_bitvec, g, p.children[i - VECEXPR_META_LENGTH], seg_buf)
    end
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
  seg_buf::OptBuffer{UInt64},
)::RuleApplicationResult
  if rule.op === (-->) # DirectedRule
    new_id::Id = instantiate_enode!(bindings, isliteral_bitvec, g, rule.right, seg_buf)
    RuleApplicationResult(:nothing, new_id, id)
  elseif rule.op === (==) # EqualityRule
    pat_to_inst = direction == 1 ? rule.right : rule.left
    new_id = instantiate_enode!(bindings, isliteral_bitvec, g, pat_to_inst, seg_buf)
    RuleApplicationResult(:nothing, new_id, id)
  elseif rule.op === (!=) # UnequalRule
    pat_to_inst = direction == 1 ? rule.right : rule.left
    other_id = instantiate_enode!(bindings, isliteral_bitvec, g, pat_to_inst, seg_buf)

    if find(g, id) == find(g, other_id)
      @debug "$rule produced a contradiction!"
      return RuleApplicationResult(:contradiction, 0, 0)
    end
    RuleApplicationResult(:nothing, 0, 0)
  elseif rule.op === (|>) # DynamicRule
    r = rule.right_fun(
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

function _eqsat_apply_impl!(
  g::EGraph,
  theory::Theory,
  rep::SaturationReport,
  params::SaturationParams,
  ematch_buffer::OptBuffer{UInt64},
)
  n_matches = 0
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

    res = apply_rule!(bindings, isliteral_bitvec, g, rule, id, direction, rule.segment_buffer)

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
  end
end

function eqsat_apply!(
  g::EGraph,
  theory::Theory,
  rep::SaturationReport,
  params::SaturationParams,
  ematch_buffer::OptBuffer{UInt64},
)
  if g.needslock
    lock(g.lock)
    try
      _eqsat_apply_impl!(g, theory, rep, params, ematch_buffer)
    finally
      unlock(g.lock)
    end
  else
    _eqsat_apply_impl!(g, theory, rep, params, ematch_buffer)
  end
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

  # Buffer for e-matching. Pre-size generously: large graphs produce many matches
  # and a small initial capacity forces many growth/copy cycles.
  ematch_buffer = OptBuffer{UInt64}(1024)

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
