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
Should return `false` if the rule `r` should be skipped
```
cansearch(s::AbstractScheduler, r::Rule)
```
"""
function cansearch end

"""
This function is called **after** pattern matching on the e-graph,
informs the scheduler about the yielded matches.
Returns `false` if the matches should not be yielded and ignored. 
```
inform!(s::AbstractScheduler, r::AbstractRule, n_matches)
```
"""
function inform! end

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
function SimpleScheduler(G::EGraph, theory::Vector{<:AbstractRule})
  SimpleScheduler()
end
inform!(s::SimpleScheduler, r, n_matches) = true
setiter!(s::SimpleScheduler, iteration) = nothing


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
  theory::Vector{<:AbstractRule}
  curr_iter::Int
  match_limit::Int 
  ban_length::Int
end

cansearch(s::BackoffScheduler, rule_idx::Int)::Bool = s.curr_iter > last(s.data[rule_idx])


function BackoffScheduler(G::EGraph, theory::Vector{<:AbstractRule}, match_limit::Int = 1000, ban_length::Int = 5)
  BackoffScheduler(fill((0,0), length(theory)), G, theory, 1, match_limit, ban_length)
end

# can saturate if there's no banned rule
cansaturate(s::BackoffScheduler)::Bool = all((<)(s.curr_iter) ∘ last, s.data)


function inform!(s::BackoffScheduler, rule_idx::Int, n_matches)
  (times_banned, _) = s.data[rule_idx]
  treshold = s.match_limit << times_banned
  if n_matches > treshold
    s.data[rule_idx] = (times_banned += 1,  s.curr_iter + (s.ban_length << times_banned))
    false
  end
  true
end

function setiter!(s::BackoffScheduler, curr_iter)
  s.curr_iter = curr_iter
end

end
