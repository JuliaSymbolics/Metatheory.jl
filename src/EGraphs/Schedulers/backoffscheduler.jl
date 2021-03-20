mutable struct BackoffSchedulerEntry
    capacity::Int
    fuel::Int
    bantime::Int
    banremaining::Int
end

isbanned(d::BackoffSchedulerEntry) = d.banremaining > 0


"""
A Rewrite Scheduler that implements exponential rule backoff.
For each rewrite, there exists a configurable initial match limit.
If a rewrite search yield more than this limit, then we ban this rule
for number of iterations, double its limit, and double the time it
will be banned next time.

This seems effective at preventing explosive rules like
associativity from taking an unfair amount of resources.
"""
struct BackoffScheduler <: AbstractScheduler
    data::Dict{Rule, BackoffSchedulerEntry}
    G::EGraph
    theory::Vector{Rule}
end

shouldskip(s::BackoffScheduler, r::Rule) = s.data[r].banremaining > 0


function BackoffScheduler(g::EGraph, theory::Vector{Rule})
    BackoffScheduler(g, theory, 8, 2)
end

function BackoffScheduler(G::EGraph, theory::Vector{Rule}, fuel::Int, bantime::Int)
    gsize = length(G.uf)
    data = Dict{Rule, BackoffSchedulerEntry}()

    # These numbers seem to fit
    for rule ∈ theory
        data[rule] = BackoffSchedulerEntry(fuel, fuel, bantime, 0)
    end

    return BackoffScheduler(data, G, theory)
end


# can saturate if there's no banned rule
cansaturate(s::BackoffScheduler) = all(kv -> !isbanned(last(kv)), s.data)

function readstep!(s::BackoffScheduler)
    for rule ∈ s.theory
        rd = s.data[rule]
        if rd.banremaining > 0
            rd.banremaining -= 1

            if rd.banremaining == 0
                # @info "unbanning rule" rule
                rd.bantime *= 2
                rd.capacity *= 2
                rd.fuel = rd.capacity
            end
        end
    end
end

function writestep!(s::BackoffScheduler, rule::Rule)
    rd = s.data[rule]

    # decrement fuel, ban rule if fuel is empty
    rd.fuel -= 1
    if rd.fuel == 0
        # @info "banning rule $rule for $(rd.bantime)!"
        rd.banremaining = rd.bantime
    end
end
