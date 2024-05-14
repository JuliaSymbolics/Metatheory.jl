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
Represents a rule scheduler for the equality saturation process

"""
abstract type AbstractScheduler end

"""
Should return `true` if the e-graph can be said to be saturated
```
cansaturate(s::AbstractScheduler)
```
"""
function cansaturate end

"""
Given a theory `t` and a rule `r` with index `i` in the theory,
should return `false` if the search for rule with index `i` should be skipped
for the current iteration.
```
cansearch(s::AbstractScheduler, i::Int)
```
"""
function cansearch end

"""
Given a theory `t` and a rule `r` with index `i` in the theory,
This function is called **after** pattern matching (searching) the e-graph,
it informs the scheduler about the number of yielded matches.
```
inform!(s::AbstractScheduler, i::Int, n_matches)
```
"""
function inform! end

"""
Inform a scheduler about the current iteration number.
```
setiter!(s::AbstractScheduler, i::Int)
```
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
cansearch(s::SimpleScheduler, r::Int) = true
function SimpleScheduler(::EGraph, ::Vector{NewRewriteRule})
  SimpleScheduler()
end
inform!(::SimpleScheduler, r, n_matches) = nothing
setiter!(::SimpleScheduler, iteration) = nothing


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
mutable struct BackoffScheduler <: AbstractScheduler
  data::Vector{Tuple{Int,Int}} # TimesBanned ⊗ BannedUntil
  G::EGraph
  theory::Vector{NewRewriteRule}
  curr_iter::Int
  match_limit::Int
  ban_length::Int
end

cansearch(s::BackoffScheduler, rule_idx::Int)::Bool = s.curr_iter > last(s.data[rule_idx])


function BackoffScheduler(G::EGraph, theory::Vector{NewRewriteRule}, match_limit::Int = 1000, ban_length::Int = 5)
  BackoffScheduler(fill((0, 0), length(theory)), G, theory, 1, match_limit, ban_length)
end

# can saturate if there's no banned rule
cansaturate(s::BackoffScheduler)::Bool = all((<)(s.curr_iter) ∘ last, s.data)


function inform!(s::BackoffScheduler, rule_idx::Int, n_matches::Int)
  (times_banned, _) = s.data[rule_idx]
  treshold = s.match_limit << times_banned
  if n_matches > treshold
    s.data[rule_idx] = (times_banned += 1, s.curr_iter + (s.ban_length << times_banned))
  end
end

function setiter!(s::BackoffScheduler, curr_iter)
  s.curr_iter = curr_iter
end

end
