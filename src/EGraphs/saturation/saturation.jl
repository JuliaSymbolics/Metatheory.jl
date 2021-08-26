import ..options
import ..@log

using .Schedulers


"""
Core algorithm of the library: the equality saturation step.
"""
function eqsat_step!(g::EGraph, theory::Vector{<:AbstractRule}, curr_iter,
        scheduler::AbstractScheduler, match_hist::MatchesBuf, 
        params::SaturationParams, report)

    instcache = Dict{AbstractRule, Dict{Sub, EClassId}}()

    setiter!(scheduler, curr_iter)

    matches = @timeit report.to "Search" eqsat_search!(g, theory, scheduler, report; threaded=params.threaded)

    # matches = setdiff!(matches, match_hist)

    @timeit report.to "Apply" eqsat_apply!(g, matches, report, params)
    

    # union!(match_hist, matches)

    if report.reason === nothing && cansaturate(scheduler) && isempty(g.dirty)
        report.reason = Saturated()
    end
    @timeit report.to "Rebuild" rebuild!(g)
   
    return report, g
end

"""
Given an [`EGraph`](@ref) and a collection of rewrite rules,
execute the equality saturation algorithm.
"""
function saturate!(g::EGraph, theory::Vector{<:AbstractRule}, params=SaturationParams())
    curr_iter = 0

    sched = params.scheduler(g, theory, params.schedulerparams...)
    match_hist = MatchesBuf()
    report = Report(g)

    if !params.timer
        disable_timer!(report.to)
    end

    while true
        curr_iter+=1

        options.printiter && @info("iteration ", curr_iter)

        report, egraph = eqsat_step!(g, theory, curr_iter, sched, match_hist, params, report)

        # report.reason == :matchlimit && break
        if !(report.reason isa Nothing)
            break
        end

        if curr_iter >= params.timeout 
            report.reason = Timeout()
            break
        end

        if params.eclasslimit > 0 && g.numclasses > params.eclasslimit 
            report.reason = EClassLimit(params.eclasslimit)
            break
        end

        if reached(g, params.goal)
            report.reason = GoalReached()
            break
        end
    end
    report.iterations = curr_iter
    @log report

    return report
end
