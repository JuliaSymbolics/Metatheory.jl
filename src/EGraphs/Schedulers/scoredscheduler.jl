mutable struct ScoredSchedulerEntry
    capacity::Int
    fuel::Int
    bantime::Int
    banremaining::Int
    weight::Int          # bantime multiplier, low = good
end

isbanned(d::ScoredSchedulerEntry)::Bool = d.banremaining > 0


"""
A Rewrite Scheduler that implements exponential rule backoff.
For each rewrite, there exists a configurable initial match limit.
If a rewrite search yield more than this limit, then we ban this rule
for number of iterations, double its limit, and double the time it
will be banned next time.

This seems effective at preventing explosive rules like
associativity from taking an unfair amount of resources.
"""
struct ScoredScheduler <: AbstractScheduler
    data::Dict{Rule, ScoredSchedulerEntry}
    G::EGraph
    theory::Vector{Rule}
end

shouldskip(s::ScoredScheduler, r::Rule)::Bool = s.data[r].banremaining > 0

function exprsize(e)
    if !(e isa Expr)
        return 1
    end

    start = Meta.isexpr(e, :call) ? 2 : 1

    c = 1 + length(e.args[start:end])
    for a ∈ e.args[start:end]
        c += exprsize(a)
    end

    return c
end

function ScoredScheduler(g::EGraph, theory::Vector{Rule})
    ScoredScheduler(g, theory, 8, 2, exprsize)
end

function ScoredScheduler(G::EGraph, theory::Vector{Rule}, fuel::Int, bantime::Int, complexity::Function)
    gsize = length(G.uf)
    data = Dict{Rule, ScoredSchedulerEntry}()

    # These numbers seem to fit
    for rule ∈ theory
        (l, r) = rule.left, rule.right
        l = l |> cleanast |> remove_assertions |> unquote_sym
        r = r |> cleanast |> remove_assertions |> unquote_sym

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
        data[rule] = ScoredSchedulerEntry(fuel, fuel, bantime, 0, w)
    end

    return ScoredScheduler(data, G, theory)
end

# can saturate if there's no banned rule
cansaturate(s::ScoredScheduler)::Bool = all(kv -> !isbanned(last(kv)), s.data)

function readstep!(s::ScoredScheduler)
    for rule ∈ s.theory
        rd = s.data[rule]
        if rd.banremaining > 0
            rd.banremaining -= 1

            if rd.banremaining == 0
                rd.bantime *= 1 + rd.weight
                rd.capacity *= (4 - rd.weight)
                rd.fuel = rd.capacity
                # @info "unbanning rule" rule rd.weight rd.bantime rd.capacity
            end
        end
    end
end

function writestep!(s::ScoredScheduler, rule::Rule)
    rd = s.data[rule]

    # decrement fuel, ban rule if fuel is empty
    rd.fuel -= 1
    if rd.fuel == 0
        # @info "banning rule!" rule rd.weight rd.bantime rd.capacity
        rd.banremaining = rd.bantime
    end
end
