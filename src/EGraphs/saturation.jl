
# const MatchesBuf = Dict{Rule,Set{Sub}}

import ..options
import ..@log

using .Schedulers


"""
Core algorithm of the library: the equality saturation step.
"""
function eqsat_step!(g::EGraph, theory::Vector{<:Rule}, mod::Module,
        scheduler::AbstractScheduler, match_hist::MatchesBuf, params::SaturationParams)

    report = Report(g)
    instcache = Dict{Rule, Dict{Sub, Int64}}()

    readstep!(scheduler)

    if options.multithreading 
        search_stats = @timed eqsat_search_threaded!(g, theory, scheduler)
    else 
        search_stats = @timed eqsat_search!(g, theory, scheduler)
    end
    matches = search_stats.value
    report.search_stats = report.search_stats + discard_value(search_stats)

    # matches = setdiff!(matches, match_hist)


    # println("============ WRITE PHASE ============")
    # println("\n $(length(matches)) $(length(match_hist))")
    # if length(matches) > matchlimit
    #     matches = matches[1:matchlimit]
    # #     # mmm = Set(collect(mmm)[1:matchlimit])
    # #     #
    # end
    # println(" diff length $(length(matches))")

    apply_stats = @timed eqsat_apply!(g, matches, scheduler, report, mod, params)
    report = apply_stats.value
    report.apply_stats = report.apply_stats + discard_value(apply_stats)

    # union!(match_hist, matches)

    # display(egraph.parents); println()
    # display(egraph.classes); println()
    if report.reason === nothing && cansaturate(scheduler) && isempty(g.dirty)
        report.reason = Saturated()
    end
    rebuild_stats = @timed rebuild!(g)
    report.rebuild_stats = report.rebuild_stats + discard_value(rebuild_stats)

    # TODO produce proofs with match_hist
    total_time!(report)

    return report, g
end

"""
Given an [`EGraph`](@ref) and a collection of rewrite rules,
execute the equality saturation algorithm.
"""
saturate!(g::EGraph, theory::Vector{<:Rule}; mod=@__MODULE__) =
    saturate!(g, theory, SaturationParams(); mod=mod)

function saturate!(g::EGraph, theory::Vector{<:Rule}, params::SaturationParams;
    mod=@__MODULE__,)
    curr_iter = 0

    sched = params.scheduler(g, theory, params.schedulerparams...)
    match_hist = MatchesBuf()
    tot_report = Report()

    # GC.enable(false)
    while true
        curr_iter+=1

        options.printiter && @info("iteration ", curr_iter)

        report, egraph = eqsat_step!(g, theory, mod, sched, match_hist, params)

        tot_report = tot_report + report

        # report.reason == :matchlimit && break
        if !(report.reason isa Nothing)
            break
        end

        if curr_iter >= params.timeout 
            tot_report.reason = Timeout()
            break
        end

        if params.eclasslimit > 0 && g.numclasses > params.eclasslimit 
            tot_report.reason = EClassLimit(params.eclasslimit)
            break
        end

        if params.stopwhen() 
            tot_report.reason = ConditionSatisfied()
            break
        end
    end
    # println(match_hist)

    # display(egraph.classes); println()
    tot_report.iterations = curr_iter
    @log tot_report
    # GC.enable(true)

    return tot_report
end
