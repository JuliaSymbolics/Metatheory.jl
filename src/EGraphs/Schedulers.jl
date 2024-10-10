module Schedulers

include("../docstrings.jl")

using Metatheory
using Metatheory.Rules
using Metatheory.EGraphs
using Metatheory.Patterns
using DocStringExtensions

import Metatheory: UNDEF_ID_VEC
import Metatheory.EGraphs: IdKey

export AbstractScheduler,
  SimpleScheduler, BackoffScheduler, FreezingScheduler, ScoredScheduler, search_matches!, cansaturate, setiter!

"""
Represents a rule scheduler for the equality saturation process

"""
abstract type AbstractScheduler end


"""
    cansaturate(s::AbstractScheduler)

Should return `true` if the e-graph can be said to be saturated
"""
function cansaturate end

"""
    search_matches!(s::AbstractScheduler, ematch_buffer::OptBuffer{UInt128}, rule_idx::Int)

Uses the scheduler `s` to search for matches for rule with index `rule_idx`.
Matches are stored in the ematch_buffer. Returns the number of matches.
"""
function search_matches! end

"""
    setiter!(s::AbstractScheduler, i::Int)

Inform a scheduler about the current iteration number.
"""
function setiter! end

"""
    rebuild!(s::AbstractScheduler, g::EGraph)

Some schedulers may hold data that need to be re-canonicalized
after an iteration of equality saturation, such as references to e-class IDs.
This is called by equality saturation after e-graph `rebuild!`
"""
function rebuild! end

# ===========================================================================
# Defaults
# ===========================================================================

@inline search_matches!(::AbstractScheduler, ::OptBuffer{UInt128}, ::Int) = 0
@inline cansaturate(::AbstractScheduler) = true
@inline setiter!(::AbstractScheduler, ::Int) = nothing
@inline rebuild!(::AbstractScheduler) = nothing




function cached_ids(g::EGraph, p::PatExpr)::Vector{Id}
  if isground(p)
    id = lookup_pat(g, p)
    iszero(id) ? UNDEF_ID_VEC : [id]
  else
    get(g.classes_by_op, IdKey(v_signature(p.n)), UNDEF_ID_VEC)
  end
end

function cached_ids(g::EGraph, p::PatLiteral)
  id = lookup_pat(g, p)
  id > 0 && return [id]
  return UNDEF_ID_VEC
end

cached_ids(g::EGraph, ::PatVar) = Iterators.map(x -> x.val, keys(g.classes))



# ===========================================================================
# SimpleScheduler
# ===========================================================================


"""
A simple Rewrite Scheduler that applies every rule every time
"""
struct SimpleScheduler <: AbstractScheduler
  g::EGraph
  theory::Theory
end

@inline cansaturate(s::SimpleScheduler) = true

"""
Apply all rules to all eclasses.
"""
function search_matches!(s::SimpleScheduler,
                         ematch_buffer::OptBuffer{UInt128},
                         rule_idx::Int)
  n_matches = 0
  rule = s.theory[rule_idx]
  for i in cached_ids(s.g, rule.left)
    n_matches += rule.ematcher_left!(s.g, rule_idx, i, rule.stack, ematch_buffer)
  end
  if is_bidirectional(rule)
    for i in cached_ids(s.g, rule.right)
      n_matches += rule.ematcher_right!(s.g, rule_idx, i, rule.stack, ematch_buffer)
    end
  end
  n_matches
end

# ===========================================================================
# BackoffScheduler
# ===========================================================================

"""
A Rewrite Scheduler that implements exponential rule backoff.
For each rewrite, there exists a configurable initial match limit.
If a rewrite search yield more than this limit, then we ban this rule
for number of iterations, double its limit, and double the time it
will be banned next time.

This seems effective at preventing explosive rules like
associativity from taking an unfair amount of resources.
"""
Base.@kwdef mutable struct BackoffScheduler <: AbstractScheduler
  const data::Vector{Tuple{Int,Int}} # TimesBanned ⊗ BannedUntil
  const g::EGraph
  const theory::Theory
  const match_limit::Int = 1000
  const ban_length::Int = 5
  curr_iter::Int = 1
end

BackoffScheduler(g::EGraph, theory::Theory; kwargs...) =
  BackoffScheduler(; data = fill((0, 0), length(theory)), g, theory, kwargs...)

# can saturate if there's no banned rule
cansaturate(s::BackoffScheduler)::Bool = all((<)(s.curr_iter) ∘ last, s.data)

function setiter!(s::BackoffScheduler, curr_iter::Int)
  s.curr_iter = curr_iter
end


function search_matches!(s::BackoffScheduler,
                         ematch_buffer::OptBuffer{UInt128},
                         rule_idx::Int)

  (times_banned, banned_until) = s.data[rule_idx]
  rule = s.theory[rule_idx]

  if s.curr_iter < banned_until
    @debug "Skipping $rule (banned $times_banned x) until $banned_until."
    return 0
  end

  threshold = s.match_limit << times_banned
  n_matches = 0
  old_ematch_buffer_size = length(ematch_buffer)
  # Search matches in the egraph with the theshold (+1) as a limit.
  # Stop early when we found more matches than the threshold
  for i in cached_ids(s.g, rule.left)
    eclass_matches = rule.ematcher_left!(s.g, rule_idx, i, rule.stack, ematch_buffer, threshold + 1 - n_matches)
    n_matches += eclass_matches
    n_matches <= threshold || break
  end
  if is_bidirectional(rule) && n_matches <= threshold
    for i in cached_ids(s.g, rule.right)
      eclass_matches = rule.ematcher_right!(s.g, rule_idx, i, rule.stack, ematch_buffer, threshold + 1 - n_matches)
      n_matches += eclass_matches
      n_matches <= threshold || break
    end
  end

  if n_matches > threshold
    ban_length = s.ban_length << times_banned
    banned_until = s.curr_iter + ban_length
    @debug "Banning $rule (banned $times_banned times) for $ban_length iterations (threshold: $threshold < $n_matches matches)."
    s.data[rule_idx] = (times_banned + 1, banned_until)
    # revert matches because the rule could be matched to eclasses only partially
    resize!(ematch_buffer, old_ematch_buffer_size)
    return 0
  end

  n_matches
end

# ===========================================================================
# FreezingScheduler
# ===========================================================================

mutable struct FreezingSchedulerStat
  times_banned::Int
  banned_until::Int
  size_limit::Int
  ban_length::Int
end

Base.@kwdef mutable struct FreezingScheduler <: AbstractScheduler
  data::Dict{Id,FreezingSchedulerStat} = Dict{Id,FreezingSchedulerStat}()
  const g::EGraph
  const theory::Theory
  const default_eclass_size_limit::Int = 10
  const default_eclass_size_increment::Int = 3
  const default_eclass_ban_length::Int = 3
  const default_eclass_ban_increment::Int = 2
  curr_iter::Int = 1
end

FreezingScheduler(g::EGraph, theory::Theory; kwargs...) = FreezingScheduler(; g, theory, kwargs...)

function Base.getindex(s::FreezingScheduler, id::Id)
  haskey(s.data, id) && return s.data[id]
  nid = find(s.g, id)
  haskey(s.data, nid) && return s.data[nid]

  s.data[id] = FreezingSchedulerStat(0, 0, s.default_eclass_size_limit, s.default_eclass_ban_length)
end

# can saturate if there's no banned rule
cansaturate(s::FreezingScheduler)::Bool = all(stat -> stat.banned_until < s.curr_iter, values(s.data))

function cansearch!(s::FreezingScheduler, eclass_id)
  stats = s[eclass_id]
  if s.curr_iter < stats.banned_until
    @debug "Skipping eclass $eclass_id (banned $(stats.times_banned) times) until $(stats.banned_until)."
    return false
  end

  threshold = stats.size_limit + s.default_eclass_size_increment * stats.times_banned
  len = length(s.g[eclass_id])
  if len > threshold
    ban_length = stats.ban_length + s.default_eclass_ban_increment * stats.times_banned
    stats.times_banned += 1
    stats.banned_until = s.curr_iter + ban_length
    @debug "Banning eclass $eclass_id (banned $(stats.times_banned) times) for $ban_length iterations (threshold: $threshold < $len nodes))."

    return false
  end

  true
end

function search_matches!(s::FreezingScheduler,
                         ematch_buffer::OptBuffer{UInt128},
                         rule_idx::Int)
  n_matches = 0
  rule = s.theory[rule_idx]
  for i in cached_ids(s.g, rule.left)
    if cansearch!(s, i)
      n_matches += rule.ematcher_left!(s.g, rule_idx, i, rule.stack, ematch_buffer)
    end
  end

  # repeat for RHS if bidirectional
  if is_bidirectional(rule)
    for i in cached_ids(s.g, rule.right)
      if cansearch!(s, i)
        n_matches += rule.ematcher_right!(s.g, rule_idx, i, rule.stack, ematch_buffer)
      end
    end
  end
  n_matches
end


function setiter!(s::FreezingScheduler, curr_iter::Int)
  s.curr_iter = curr_iter
end

function rebuild!(s::FreezingScheduler)
  new_data = Dict{Id,FreezingSchedulerStat}()
  for (id, stats) in s.data
    new_data[find(s.g, id)] = stats
  end
  finalize(s.data)
  s.data = new_data
  true
end

end
