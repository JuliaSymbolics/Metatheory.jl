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
@with_kw mutable struct SaturationParams
  timeout::Int = 8
  timelimit::Period = Second(-1)
  # default sizeout. TODO make this bytes
  # sizeout::Int = 2^14
  matchlimit::Int                      = 5000
  eclasslimit::Int                     = 5000
  enodelimit::Int                      = 15000
  goal::Union{Nothing,SaturationGoal}  = nothing
  stopwhen::Function                   = () -> false
  scheduler::Type{<:AbstractScheduler} = BackoffScheduler
  schedulerparams::Tuple               = ()
  threaded::Bool                       = false
  timer::Bool                          = true
  printiter::Bool                      = false
end

struct Match
  rule::AbstractRule
  # the rhs pattern to instantiate 
  pat_to_inst
  # the substitution
  sub::Sub
  # the id the matched the lhs  
  id::EClassId
end

function cached_ids(g::EGraph, p::AbstractPat)# ::Vector{Int64}
  if isground(p)
    id = lookup_pat(g, p)
    !isnothing(id) && return [id]
  else
    return collect(keys(g.classes))
  end
  return []
end

function cached_ids(g::EGraph, p) # p is a literal
  id = lookup(g, ENodeLiteral(p))
  !isnothing(id) && return [id]
  return []
end

# FIXME 
function cached_ids(g::EGraph, p::PatTerm)
  # cached = get(g.symcache, p.head, Set{Int64}())
  # appears = Set{Int64}() 
  # for (id, class) ∈ g.classes 
  #     for n ∈ class 
  #         if n.head == p.head
  #             push!(appears, id) 
  #         end
  #     end
  # end
  # if !(cached == appears)
  #     @show cached 
  #     @show appears
  # end

  collect(keys(g.classes))
  # cached
  # get(g.symcache, p.head, [])
end

# function cached_ids(g::EGraph, p::PatLiteral)
#     get(g.symcache, p.val, [])
# end


function (r::BidirRule)(g::EGraph, id::EClassId)
  vcat(
    ematch(g, r.ematch_program_l, id) .|> sub -> Match(r, r.right, sub, id),
    ematch(g, r.ematch_program_r, id) .|> sub -> Match(r, r.left, sub, id),
  )
end


"""
Returns an iterator of `Match`es.
"""
function eqsat_search!(
  egraph::EGraph,
  theory::Vector{<:AbstractRule},
  scheduler::AbstractScheduler,
  report::SaturationReport
)::Int
  for (rule_idx, rule) in other_rules
    @timeit report.to repr(rule) begin
      # don't apply banned rules
      if !cansearch(scheduler, rule)
        continue
      end
      # ids = cached_ids(egraph, rule.left)
      for i in keys(g.classes) 
        n_matches += rule.ematcher!(egraph, rule_idx, i)
      end
      # TODO can_yield = inform!(scheduler, rule, n_matches)
    end
  end

  return n_matches
end


function drop_n!(D::CircularDeque, nn)
  D.n -= nn
  tmp = D.first + nn
  D.first = tmp > D.capacity ?  1 : tmp
end

instantiate_enode!(g::EGraph, pat::Any)::EClassId = add!(g, ENodeLiteral(pat)).id
instantiate_enode!(g::EGraph, p::PatVar)::EClassId = g.match_buffer[p.idx][1]
function instantiate_enode!(g::EGraph, p::PatTerm)::EClassId = g.match_buffer[p.idx][1]
  eh = exprhead(pat)
  op = operation(pat)
  ar = arity(pat)
  T = gettermtype(g, op, ar)
  add!(g, ENodeTerm{}(eh, op, map!(x -> instantiate_enode!(g, x), arguments(pat)))).id
end

function apply_rule!(g::EGraph, rule::RewriteRule, id, direction)
  merge!(g, id, instantiate_enode!(g, rule.right))
  nothing
end


function apply_rule!(g::EGraph, rule::UnequalRule, id, direction)
  pat_to_inst = direction == 1 ? rule.right : rule.left
  other_id = instantiate_enode!(g, pat_to_inst)

  if find(g, id) == find(g, other_id)
    @log "Contradiction!" rule
    return :contradiction
  end
  nothing
end

"""
Instantiate argument for dynamic rule application in e-graph
"""
function instantiate_actual_param!(g::EGraph, i)
  ecid, literal_position = g.match_buffer[i]
  ecid <= 0 && error("unbound pattern variable $pat in rule $rule")
  if literal_position > 0
    eclass = g[ecid]
    @assert eclass[literal_position] isa ENodeLiteral
    return eclass[literal_position].value # TODO getliteral from e-class
  end
  return eclass
end

function apply_rule!(g::EGraph, rule::DynamicRule, id, direction)
  f = rule.rhs_fun
  r = f(id, g, (instantiate_actual_param!(g, i) for i in 1:length(rule.pvars))...)
  isnothing(r) && return nothing
  rc, node = addexpr!(g, r)
  merge!(g, id, rc.id)
  return nothing
end



function eqsat_apply!(g::EGraph, theory::Vector{<:AbstractRule}, rep::SaturationReport, params::SaturationParams)
  i = 0
  lock(g.match_buffer_lock) do 
    while !isempty(g.match_buffer)
      if reached(g, params.goal)
        @log "Goal reached"
        rep.reason = :goalreached
        return
      end

      rule_idx, id = popfirst!(g.match_buffer)
      direction = sign(rule_idx)
      rule_idx = abs(rule_idx)
      rule = theory[rule_idx]

      halt_reason = apply_rule!(g, rule, id, direction)
      drop_n!(g.match_buffer, npvars)
      @assert popfirst!(g.match_buffer) == (0,0)

      if (halt_reason !== nothing)
        rep.reason = halt_reason
        return
      end
    end
  end
end

import ..@log


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

  n_matches = @timeit report.to "Search" eqsat_search!(g, theory, scheduler, report)

  @timeit report.to "Apply" eqsat_apply!(g, n_matches, report, params)

  if report.reason === nothing && cansaturate(scheduler) && isempty(g.dirty)
    report.reason = :saturated
  end
  @timeit report.to "Rebuild" rebuild!(g)

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

  start_time = Dates.now().instant

  !params.timer && disable_timer!(report.to)
  timelimit = params.timelimit > Second(0)


  while true
    curr_iter += 1

    params.printiter && @info("iteration ", curr_iter)

    report = eqsat_step!(g, theory, curr_iter, sched, params, report)

    elapsed = Dates.now().instant - start_time

    if timelimit && params.timelimit <= elapsed
      report.reason = :timelimit
      break
    end

    # report.reason == :matchlimit && break
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
  @log report

  return report
end

function areequal(theory::Vector, exprs...; params = SaturationParams())
  g = EGraph(exprs[1])
  areequal(g, theory, exprs...; params = params)
end

function areequal(g::EGraph, t::Vector{<:AbstractRule}, exprs...; params = SaturationParams())
  @log "Checking equality for " exprs
  if length(exprs) == 1
    return true
  end
  # rebuild!(G)

  @log "starting saturation"

  n = length(exprs)
  ids = Vector{EClassId}(undef, n)
  nodes = Vector{AbstractENode}(undef, n)
  for i in 1:n
    ec, node = addexpr!(g, exprs[i])
    ids[i] = ec.id
    nodes[i] = node
  end

  goal = EqualityGoal(collect(exprs), ids)

  # alleq = () -> (all(x -> in_same_set(G.uf, ids[1], x), ids[2:end]))

  params.goal = goal
  # params.stopwhen = alleq

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
