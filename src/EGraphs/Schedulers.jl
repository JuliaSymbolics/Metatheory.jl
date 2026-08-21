"""
    Schedulers

Scheduler implementations for e-graph rule search.

Custom schedulers subtype [`AbstractScheduler`](@ref Metatheory.EGraphs.Schedulers.AbstractScheduler) and implement
`cansaturate`, `cansearch`, `inform!`, and `setiter!`.
"""
module Schedulers

include("../docstrings.jl")

import Metatheory.Rules: AbstractRule, DynamicRule
import Metatheory.EGraphs: EGraph
import Metatheory.Patterns: PatTerm

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

Abstract interface for controlling rule search during [`saturate!`](@ref Metatheory.EGraphs.saturate!).

A custom scheduler must provide a constructor accepting an [`EGraph`](@ref Metatheory.EGraphs.EGraph)
and a vector of [`AbstractRule`](@ref Metatheory.Rules.AbstractRule)s, plus methods for [`cansaturate`](@ref Metatheory.EGraphs.Schedulers.cansaturate),
[`cansearch`](@ref Metatheory.EGraphs.Schedulers.cansearch), [`inform!`](@ref Metatheory.EGraphs.Schedulers.inform!), and [`setiter!`](@ref Metatheory.EGraphs.Schedulers.setiter!). The scheduler
may keep mutable state, but it must return a Boolean from the first three hooks.
"""
abstract type AbstractScheduler end

"""
    cansaturate(scheduler) -> Bool

Return `true` when the scheduler has no rule search left to perform. This is
checked after each saturation iteration; returning `false` lets another stop
condition, such as a goal or timeout, decide when to stop.

Implement this method for custom [`AbstractScheduler`](@ref Metatheory.EGraphs.Schedulers.AbstractScheduler) types.
"""
function cansaturate end

"""
    cansearch(scheduler, rule) -> Bool

Return `true` when `rule` should be searched during the current iteration and
`false` when the scheduler wants to skip it.

Implement this method for custom [`AbstractScheduler`](@ref Metatheory.EGraphs.Schedulers.AbstractScheduler) types.
"""
function cansearch end

"""
    inform!(scheduler, rule, n_matches) -> Bool

Notify the scheduler how many matches were produced for `rule` in the current
iteration. Return `true` to keep the matches and `false` to discard them.

Implement this method for custom [`AbstractScheduler`](@ref Metatheory.EGraphs.Schedulers.AbstractScheduler) types.
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
    SimpleScheduler()

A scheduler that searches every rule on every iteration and never stops due to
scheduler state. It is useful as a reference implementation for custom
schedulers and for small theories.

The scheduler constructor used by [`saturate!`](@ref Metatheory.EGraphs.saturate!) is
`SimpleScheduler(egraph, theory)`; the arguments are accepted for interface
compatibility and are not stored.
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
    BackoffScheduler(egraph, theory[, match_limit, ban_length])

A scheduler that applies exponential rule backoff. When a rule yields more
than its match limit, it is skipped for a number of iterations; both limits
grow after each ban. This bounds explosive theories such as associativity.

# Arguments

- `egraph`: E-graph being saturated.
- `theory`: Rules being searched.
- `match_limit::Int=1000`: Initial matches permitted for one rule.
- `ban_length::Int=5`: Initial number of iterations to skip after a ban.

# Fields

- `data`: Per-rule backoff state.
- `G`, `theory`, `curr_iter`: E-graph, rule collection, and iteration state.
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
  threshold = rd.match_limit << rd.times_banned
  if n_matches > threshold
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
    ScoredScheduler(egraph, theory[, match_limit, ban_length, complexity])

A backoff scheduler that weights rules by how their complexity changes. Rules
that increase expression complexity are penalized more heavily than rules that
reduce it.

# Arguments

- `egraph`: E-graph being saturated.
- `theory`: Rules being searched.
- `match_limit::Int=1000`: Initial matches permitted for one rule.
- `ban_length::Int=5`: Initial number of iterations to skip after a ban.
- `complexity`: Callable returning a comparable complexity score for a pattern.

# Fields

- `data`: Per-rule match limits, weights, and ban state.
- `G`, `theory`, `curr_iter`: E-graph, rule collection, and iteration state.
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
  threshold = rd.match_limit * (rd.weight^rd.times_banned)
  if n_matches > threshold
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
