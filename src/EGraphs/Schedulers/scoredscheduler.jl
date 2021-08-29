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
    data::IdDict{AbstractRule, ScoredSchedulerEntry}
    G::EGraph
    theory::Vector{<:AbstractRule}
    curr_iter::Int
end

cansearch(s::ScoredScheduler, r::AbstractRule)::Bool = s.curr_iter > s.data[r].banned_until

exprsize(a) = 1

function exprsize(e::PatTerm) 
    c = 1 + length(e.args)
    for a ∈ e.args
        c += exprsize(a)
    end
    return c
end

function exprsize(e::Expr)
    start = Meta.isexpr(e, :call) ? 2 : 1

    c = 1 + length(e.args[start:end])
    for a ∈ e.args[start:end]
        c += exprsize(a)
    end

    return c
end

function ScoredScheduler(g::EGraph, theory::Vector{<:AbstractRule})
    # BackoffScheduler(g, theory, 128, 4)
    ScoredScheduler(g, theory, 1000, 5, exprsize)
end

function ScoredScheduler(G::EGraph, theory::Vector{<:AbstractRule}, match_limit::Int, ban_length::Int, complexity::Function)
    gsize = length(G.uf)
    data = IdDict{AbstractRule, ScoredSchedulerEntry}()

    for rule ∈ theory
        if rule isa DynamicRule
            w = 2
            data[rule] = ScoredSchedulerEntry(match_limit, ban_length, 0, 0, w)
            continue
        end
        (l, r) = rule.left, rule.right

        cl = complexity(l)
        cr = complexity(r)
        # println("$rule HAS SCORE $((cl, cr))")
        if cl > cr
            w = 1   # reduces complexity
        elseif cr > cl
            w = 3   # augments complexity
        else
            w = 2   # complexity is equal
        end
        # println(w)
        data[rule] = ScoredSchedulerEntry(match_limit, ban_length, 0, 0, w)
    end

    return ScoredScheduler(data, G, theory, 1)
end

# can saturate if there's no banned rule
cansaturate(s::ScoredScheduler)::Bool = all(kv -> s.curr_iter > last(kv).banned_until, s.data)


function inform!(s::ScoredScheduler, rule::AbstractRule, n_matches)
    # println(s.data[rule])

    rd = s.data[rule]
    treshold = rd.match_limit * (rd.weight^rd.times_banned)
    if length(n_matches) > treshold
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