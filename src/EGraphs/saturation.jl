const Match = Tuple{Rule, Sub, Int64}
const MatchesBuf = Vector{Match}

import ..genrhsfun
import ..options
import ..@log

using .Schedulers

function inst(pat, sub::Sub)
    # TODO interface istree
    if haskey(sub, pat)
        (eclass, lit) = sub[pat]
        lit != nothing ? lit : eclass
    else
        pat
    end
end

function instantiate(p, sub::Sub; skip_assert=false)
    # remove type assertions
    if skip_assert
        p = df_walk( x -> (isexpr(x, :(::)) ? x.args[1] : x), p; skip_call=true )
    end

    df_walk(inst, p, sub; skip_call=true)
end

"""
Core algorithm of the library: the equality saturation step.
"""
function eqsat_step!(egraph::EGraph, theory::Vector{Rule};
        scheduler=SimpleScheduler(), mod=@__MODULE__,
        match_hist=MatchesBuf(), sizeout=0, stopwhen=()->false,
        matchlimit=5000 # max number of matches
        )
    matches=MatchesBuf()
    EMPTY_DICT = Sub()

    readstep!(scheduler)

    report = Report(egraph)

    search_stats = @timed for rule ∈ theory
        # don't apply banned rules
        shouldskip(scheduler, rule) && continue

        if rule.mode ∉ [:rewrite, :dynamic, :equational]
            error("unsupported mode in rule ", rule)
        end

        # outermost symbol in lhs
        sym = getfunsym(rule.left)
        if istree(rule.left)
            ids = get(egraph.symcache, sym, [])
        else
            ids = keys(egraph.M)
        end

        for id ∈ ids
            for sub in ematch(egraph, rule.left, id, EMPTY_DICT)
                # display(sub); println()
                !isempty(sub) && push!(matches, (rule, sub, id))
            end
        end

        if rule.mode == :equational
            sym = getfunsym(rule.right)
            ids = get(egraph.symcache, sym, [])
            for id ∈ ids
                for sub in ematch(egraph, rule.right, id, EMPTY_DICT)
                    # display(sub); println()
                    !isempty(sub) && push!(matches, (rule, sub, id))
                end
            end
        end
    end
    report.search_stats = report.search_stats + discard_value(search_stats)


    # mmm = unique(matches)
    # mmm = symdiff(match_hist, matches)

    mmm = setdiff(matches, match_hist)

    if length(mmm) > matchlimit
        mmm = mmm[1:matchlimit]
        #
        # report.reason = :matchlimit
        # @goto quit_rebuild
    end

    # println("============ WRITE PHASE ============")
    # println("\n $(length(matches)) $(length(match_hist))")
    # println(" diff length $(length(mmm))")

    i = 0

    apply_stats = @timed for match ∈ mmm
        i += 1
        (rule, sub, id) = match

        if i % 300 == 0
            # println("rebuilding")

            if sizeout > 0 && length(egraph.U) > sizeout
                @log "E-GRAPH SIZEOUT"
                report.reason = :sizeout
                @goto quit_rebuild
            end

            if stopwhen()
                @log "Halting requirement satisfied"
                report.reason = :condition
                @goto quit_rebuild
            end
        end

        writestep!(scheduler, rule)

        if rule.mode == :rewrite || rule.mode == :equational # symbolic replacement
            l = instantiate(rule.left, sub; skip_assert=true)
            r = instantiate(rule.right, sub)
            lc = addexpr!(egraph, l)
            rc = addexpr!(egraph, r)
            merge!(egraph, lc.id, rc.id)
        elseif rule.mode == :dynamic # execute the right hand!
            l = instantiate(rule.left,sub; skip_assert=true)
            lc = addexpr!(egraph, l)

            (params, f) = rule.right_fun[mod]
            actual_params = map(params) do x
                (eclass, literal) = sub[x]
                literal != nothing ? literal : eclass
            end
            new = f(egraph, actual_params...)
            rc = addexpr!(egraph, new)
            merge!(egraph,lc.id,rc.id)
        else
            error("unsupported rule mode")
        end
    end
    report.apply_stats = report.apply_stats + discard_value(apply_stats)

    union!(match_hist, mmm)

    # display(egraph.parents); println()
    # display(egraph.M); println()
    @label quit_rebuild
    report.saturated = isempty(egraph.dirty) && report.reason == nothing
    rebuild_stats = @timed rebuild!(egraph)
    report.rebuild_stats = report.rebuild_stats + discard_value(rebuild_stats)


    total_time!(report)

    return report, egraph
end

# TODO plot how egraph shrinks and grows during saturation
"""
Given an [`EGraph`](@ref) and a collection of rewrite rules,
execute the equality saturation algorithm.
"""
function saturate!(egraph::EGraph, theory::Vector{Rule};
    mod=@__MODULE__,
    timeout=0, stopwhen=(()->false), sizeout=2^12,
    matchlimit=5000,
    scheduler::Type{<:AbstractScheduler}=BackoffScheduler)

    if timeout == 0
        timeout = length(theory)
    end

    curr_iter = 0

    # prepare the dynamic rules in this module
    for rule ∈ theory
        if rule.mode == :dynamic && !haskey(rule.right_fun, mod)
            rule.right_fun[mod] = genrhsfun(rule.left, rule.right, mod)
        end
    end

    # init the scheduler
    sched = scheduler(egraph, theory)

    match_hist = MatchesBuf()

    tot_report = Report()

    while true
        curr_iter+=1

        options[:printiter] && @info("iteration ", curr_iter)

        report, egraph = eqsat_step!(egraph, theory;
            scheduler=sched, mod=mod,
            match_hist=match_hist, sizeout=sizeout,
            matchlimit=matchlimit,
            stopwhen=stopwhen)

        tot_report = tot_report + report

        report.reason == :matchlimit && break
        cansaturate(sched) && report.saturated && (tot_report.saturated = true; break)
        curr_iter >= timeout && (tot_report.reason = :timeout; break)
        sizeout > 0 && length(egraph.U) > sizeout && (tot_report.reason = :sizeout; break)
        stopwhen() && (tot_report.reason = :condition; break)
    end
    # println(match_hist)
    tot_report.iterations = curr_iter
    @log tot_report


    return tot_report
end
