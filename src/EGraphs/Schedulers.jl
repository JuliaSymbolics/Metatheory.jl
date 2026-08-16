"""
    Schedulers

Scheduler implementations for e-graph rule search.

Custom schedulers subtype [`AbstractScheduler`](@ref) and implement
`cansaturate`, `cansearch`, `inform!`, and `setiter!`.
"""
module Schedulers

include("../docstrings.jl")

using Metatheory.Rules
using Metatheory.EGraphs
using Metatheory.Patterns
using DocStringExtensions

export AbstractScheduler
export SimpleScheduler
export BackoffScheduler
export ScoredScheduler
export cansaturate
export cansearch
export inform!
export setiter!

"""
    AbstractScheduler

Abstract interface for controlling rule search during [`saturate!`](@ref).

A custom scheduler must provide a constructor accepting an [`EGraph`](@ref)
and a vector of [`AbstractRule`](@ref)s, plus methods for [`cansaturate`](@ref),
[`cansearch`](@ref), [`inform!`](@ref), and [`setiter!`](@ref). The scheduler
may keep mutable state, but it must return a Boolean from the first three hooks.
"""
abstract type AbstractScheduler end

"""
    cansaturate(scheduler) -> Bool

Return `true` when the scheduler has no rule search left to perform. This is
checked after each saturation iteration; returning `false` lets another stop
condition, such as a goal or timeout, decide when to stop.

Implement this method for custom [`AbstractScheduler`](@ref) types.
"""
function cansaturate end

"""
    cansearch(scheduler, rule) -> Bool

Return `true` when `rule` should be searched during the current iteration and
`false` when the scheduler wants to skip it.

Implement this method for custom [`AbstractScheduler`](@ref) types.
"""
function cansearch end

"""
    inform!(scheduler, rule, n_matches) -> Bool

Notify the scheduler how many matches were produced for `rule` in the current
iteration. Return `true` to keep the matches and `false` to discard them.

Implement this method for custom [`AbstractScheduler`](@ref) types.
"""
function inform! end

"""
    setiter!(scheduler, iteration)

Notify a scheduler that saturation has advanced to `iteration`.

Custom schedulers should update any state used by `cansearch` or
`cansaturate`. The default scheduler interface returns `nothing`.
"""
function setiter! end

# ===========================================================================
# SimpleScheduler
# ===========================================================================


"""
A simple Rewrite Scheduler that applies every rule every time
"""
struct SimpleScheduler <: AbstractScheduler end

cansaturate(s::SimpleScheduler) = true
cansearch(s::SimpleScheduler, r::AbstractRule) = true
function SimpleScheduler(G::EGraph, theory::Vector{<:AbstractRule})
  SimpleScheduler()
end
inform!(s::SimpleScheduler, r, n_matches) = true
setiter!(s::SimpleScheduler, iteration) = nothing


# ===========================================================================
# BackoffScheduler
# ===========================================================================

mutable struct BackoffSchedulerEntry
  match_limit::Int
  ban_length::Int
  times_banned::Int
  banned_until::Int
end

"""
A Rewrite Scheduler that implements exponential rule backoff.
For each rewrite, there exists a configurable initial match limit.
If a rewrite search yield more than this limit, then we ban this rule
for number of iterations, double its limit, and double the time it
will be banned next time.

This seems effective at preventing explosive rules like
associativity from taking an unfair amount of resources.
"""
mutable struct BackoffScheduler <: AbstractScheduler
  data::IdDict{AbstractRule,BackoffSchedulerEntry}
  G::EGraph
  theory::Vector{<:AbstractRule}
  curr_iter::Int
end

cansearch(s::BackoffScheduler, r::AbstractRule)::Bool = s.curr_iter > s.data[r].banned_until


function BackoffScheduler(g::EGraph, theory::Vector{<:AbstractRule})
  # BackoffScheduler(g, theory, 128, 4)
  BackoffScheduler(g, theory, 1000, 5)
end

function BackoffScheduler(G::EGraph, theory::Vector{<:AbstractRule}, match_limit::Int, ban_length::Int)
  gsize = length(G.uf)
  data = IdDict{AbstractRule,BackoffSchedulerEntry}()

  for rule in theory
    data[rule] = BackoffSchedulerEntry(match_limit, ban_length, 0, 0)
  end

  return BackoffScheduler(data, G, theory, 1)
end

# can saturate if there's no banned rule
cansaturate(s::BackoffScheduler)::Bool = all(kv -> s.curr_iter > last(kv).banned_until, s.data)


function inform!(s::BackoffScheduler, rule::AbstractRule, n_matches)
  rd = s.data[rule]
  treshold = rd.match_limit << rd.times_banned
  if n_matches > treshold
    ban_length = rd.ban_length << rd.times_banned
    rd.times_banned += 1
    rd.banned_until = s.curr_iter + ban_length
    return false
  end
  return true
end

function setiter!(s::BackoffScheduler, curr_iter)
  s.curr_iter = curr_iter
end

# ===========================================================================
# ScoredScheduler
# ===========================================================================


mutable struct ScoredSchedulerEntry
  match_limit::Int
  ban_length::Int
  times_banned::Int
  banned_until::Int
  weight::Int
end

"""
A Rewrite Scheduler that implements exponential rule backoff.
For each rewrite, there exists a configurable initial match limit.
If a rewrite search yield more than this limit, then we ban this rule
for number of iterations, double its limit, and double the time it
will be banned next time.

This seems effective at preventing explosive rules like
associativity from taking an unfair amount of resources.
"""
mutable struct ScoredScheduler <: AbstractScheduler
  data::IdDict{AbstractRule,ScoredSchedulerEntry}
  G::EGraph
  theory::Vector{<:AbstractRule}
  curr_iter::Int
end

cansearch(s::ScoredScheduler, r::AbstractRule)::Bool = s.curr_iter > s.data[r].banned_until

exprsize(a) = 1

function exprsize(e::PatTerm)
  c = 1 + length(e.args)
  for a in e.args
    c += exprsize(a)
  end
  return c
end

function exprsize(e::Expr)
  start = Meta.isexpr(e, :call) ? 2 : 1

  c = 1 + length(e.args[start:end])
  for a in e.args[start:end]
    c += exprsize(a)
  end

  return c
end

function ScoredScheduler(g::EGraph, theory::Vector{<:AbstractRule})
  # BackoffScheduler(g, theory, 128, 4)
  ScoredScheduler(g, theory, 1000, 5, exprsize)
end

function ScoredScheduler(
  G::EGraph,
  theory::Vector{<:AbstractRule},
  match_limit::Int,
  ban_length::Int,
  complexity::Function,
)
  gsize = length(G.uf)
  data = IdDict{AbstractRule,ScoredSchedulerEntry}()

  for rule in theory
    if rule isa DynamicRule
      w = 2
      data[rule] = ScoredSchedulerEntry(match_limit, ban_length, 0, 0, w)
      continue
    end
    (l, r) = rule.left, rule.right

    cl = complexity(l)
    cr = complexity(r)
    if cl > cr
      w = 1   # reduces complexity
    elseif cr > cl
      w = 3   # augments complexity
    else
      w = 2   # complexity is equal
    end
    data[rule] = ScoredSchedulerEntry(match_limit, ban_length, 0, 0, w)
  end

  return ScoredScheduler(data, G, theory, 1)
end

# can saturate if there's no banned rule
cansaturate(s::ScoredScheduler)::Bool = all(kv -> s.curr_iter > last(kv).banned_until, s.data)


function inform!(s::ScoredScheduler, rule::AbstractRule, n_matches)
  rd = s.data[rule]
  treshold = rd.match_limit * (rd.weight^rd.times_banned)
  if n_matches > treshold
    ban_length = rd.ban_length * (rd.weight^rd.times_banned)
    rd.times_banned += 1
    rd.banned_until = s.curr_iter + ban_length
    # @info "banning rule $rule until $(rd.banned_until)!"
    return false
  end
  return true
end

function setiter!(s::ScoredScheduler, curr_iter)
  s.curr_iter = curr_iter
end


end
