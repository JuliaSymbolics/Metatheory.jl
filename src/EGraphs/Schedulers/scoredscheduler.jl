mutable struct ScoredSchedulerEntry
    capacity::Int
    fuel::Int
    bantime::Int
    banremaining::Int
    score::Int          # bantime multiplier, low = good
end

isbanned(d::ScoredSchedulerEntry) = d.banremaining > 0


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

shouldskip(s::ScoredScheduler, r::Rule) = s.data[r].banremaining > 0

using MatchCore
function score(r::Rule)
    @smatch r.expr begin
        # associativity
        :( ($f)($a, ($&f)($b, $c)) => ($&f)(($&f)($&a, $&b), $&c)) => 3
        :( ($f)(($&f)($a, $b), $c) => ($&f)($&a, ($&f)($&b, $&c))) => 3
        :( ($f)($a, ($&f)($b, $c)) == ($&f)(($&f)($&a, $&b), $&c)) => 3
        :( ($f)(($&f)($a, $b), $c) == ($&f)($&a, ($&f)($&b, $&c))) => 3
        :( ($f)($a, $b) => ($&f)($&b, $&a)) => 3
        :( ($f)($a, $b) == ($&f)($&b, $&a)) => 3
        :($i) => 1
    end
end

function ScoredScheduler(G::EGraph, theory::Vector{Rule})
    gsize = length(G.U)
    data = Dict{Rule, ScoredSchedulerEntry}()

    # These numbers seem to fit
    for rule ∈ theory
        s = score(rule)
        println("$rule HAS SCORE $s")
        data[rule] = ScoredSchedulerEntry(8, 8, 2 * s, 0, s)
    end

    return ScoredScheduler(data, G, theory)
end

# can saturate if there's no banned rule
cansaturate(s::ScoredScheduler) = all(kv -> !isbanned(last(kv)), s.data)

function readstep!(s::ScoredScheduler)
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

function writestep!(s::ScoredScheduler, rule::Rule)
    rd = s.data[rule]

    # decrement fuel, ban rule if fuel is empty
    rd.fuel -= 1
    if rd.fuel == 0
        # @info "banning rule!" rule
        rd.banremaining = rd.bantime
    end
end
