module Schedulers

include("../docstrings.jl")

using Metatheory.Rules
using Metatheory.EGraphs
using Metatheory.Patterns
using DocStringExtensions

export AbstractScheduler,
  SimpleScheduler, BackoffScheduler, FreezingScheduler, ScoredScheduler, cansaturate, cansearch, inform!, setiter!

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
    cansearch(s::AbstractScheduler, i::Int)
    cansearch(s::AbstractScheduler, i::Int, eclass_id::Id)

Given a theory `t` and a rule `r` with index `i` in the theory,
should return `false` if the search for rule with index `i` should be skipped
for the current iteration. An extra `eclass_id::Id` arguments can be passed 
in order to filter out specific e-classes.
"""
function cansearch end

"""
    inform!(s::AbstractScheduler, i::Int, n_matches)
    inform!(s::AbstractScheduler, i::Int, eclass_id::Id, n_matches)


Given a theory `t` and a rule `r` with index `i` in the theory,
This function is called **after** pattern matching (searching) the e-graph,
it informs the scheduler about the number of yielded matches.
"""
function inform! end

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
# SimpleScheduler
# ===========================================================================


"""
A simple Rewrite Scheduler that applies every rule every time
"""
struct SimpleScheduler <: AbstractScheduler end

cansaturate(s::SimpleScheduler) = true
@inline cansearch(s::SimpleScheduler, ::Int) = true
@inline cansearch(s::SimpleScheduler, ::Int, ::Id) = true

function SimpleScheduler(::EGraph, ::Theory)
  SimpleScheduler()
end
@inline inform!(::SimpleScheduler, ::Int, ::Int) = nothing
@inline inform!(::SimpleScheduler, ::Int, ::Id, ::Int) = nothing
@inline setiter!(::SimpleScheduler, ::Int) = nothing
@inline rebuild!(::SimpleScheduler, ::EGraph) = nothing

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
  data::Vector{Tuple{Int,Int}} # TimesBanned ⊗ BannedUntil
  g::EGraph
  theory::Theory
  curr_iter::Int = 1
  match_limit::Int = 1000
  ban_length::Int = 5
end

@inline cansearch(s::BackoffScheduler, rule_idx::Int)::Bool = s.curr_iter > last(s.data[rule_idx])
@inline cansearch(s::BackoffScheduler, rule_idx::Int, eclass_id::Id) = true

BackoffScheduler(g::EGraph, theory::Theory; kwargs...) =
  BackoffScheduler(; data = fill((0, 0), length(theory)), g, theory, kwargs...)

# can saturate if there's no banned rule
cansaturate(s::BackoffScheduler)::Bool = all((<)(s.curr_iter) ∘ last, s.data)


function inform!(s::BackoffScheduler, rule_idx::Int, n_matches::Int)
  (times_banned, _) = s.data[rule_idx]
  threshold = s.match_limit << times_banned
  if n_matches > threshold
    s.data[rule_idx] = (times_banned += 1, s.curr_iter + (s.ban_length << times_banned))
  end
end

@inline inform!(::BackoffScheduler, ::Int, ::Id, ::Int) = nothing

function setiter!(s::BackoffScheduler, curr_iter)
  s.curr_iter = curr_iter
end

@inline rebuild!(::BackoffScheduler, ::EGraph) = nothing

# ===========================================================================
# FreezingScheduler
# ===========================================================================

struct FreezingSchedulerStat
  times_banned::Int
  banned_until::Int
  size_limit::Int
  ban_length::Int
end

Base.@kwdef mutable struct FreezingScheduler <: AbstractScheduler
  data::Dict{Id,FreezingSchedulerStat} = Dict{Id,FreezingSchedulerStat}()
  g::EGraph
  theory::Theory
  curr_iter::Int = 1
  default_eclass_size_limit::Int = 10
  default_eclass_size_increment::Int = 3
  default_eclass_ban_length::Int = 3
  default_eclass_ban_increment::Int = 2
end

FreezingScheduler(g::EGraph, theory::Theory; kwargs...) = FreezingScheduler(; g, theory, kwargs...)

@inline cansearch(s::FreezingScheduler, rule_idx::Int)::Bool = true
@inline cansearch(s::FreezingScheduler, ::Int, eclass_id::Id) = s.curr_iter > s[eclass_id].banned_until

function Base.getindex(s::FreezingScheduler, id::Id)
  haskey(s.data, id) && return s.data[id]
  nid = find(s.g, id)
  haskey(s.data, nid) && return s.data[nid]

  data[id] = FreezingSchedulerStat(0, 0, s.default_eclass_size_limit, s.default_eclass_ban_length)
end

# can saturate if there's no banned rule
cansaturate(s::FreezingScheduler)::Bool = all(stat -> stat.banned_until < s.curr_iter, values(s.data))

@inline inform!(::FreezingScheduler, ::Int, ::Id) = nothing

function inform!(s::FreezingScheduler, rule_idx::Int, n_matches::Int, eclass_id::Id)
  stats = s[eclass_id]
  threshold = stats.size_limit + s.default_eclass_size_increment * stats.times_banned
  len = length(s.g[eclass_id])

  if len > threshold
    ban_length = stats.ban_length + s.default_eclass_ban_increment * stats.times_banned
    stats.times_banned += 1
    stats.banned_until = s.curr_iter + ban_length
  end
end

function setiter!(s::FreezingScheduler, curr_iter)
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
