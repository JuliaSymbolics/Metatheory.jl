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
    data::IdDict{AbstractRule, BackoffSchedulerEntry}
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
    data = IdDict{AbstractRule, BackoffSchedulerEntry}()

    for rule ∈ theory
        data[rule] = BackoffSchedulerEntry(match_limit, ban_length, 0, 0)
    end

    return BackoffScheduler(data, G, theory, 1)
end

# can saturate if there's no banned rule
cansaturate(s::BackoffScheduler)::Bool = all(kv -> s.curr_iter > last(kv).banned_until, s.data)


function inform!(s::BackoffScheduler, rule::AbstractRule, n_matches)
    # println(s.data[rule])

    rd = s.data[rule]
    treshold = rd.match_limit << rd.times_banned
    if n_matches > treshold
        ban_length = rd.ban_length << rd.times_banned
        rd.times_banned += 1
        rd.banned_until = s.curr_iter + ban_length
        # @info "banning rule $rule until $(rd.banned_until)!"
        return false
    end
    return true
end

function setiter!(s::BackoffScheduler, curr_iter)
    s.curr_iter = curr_iter
end