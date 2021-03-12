const Match = Tuple{Rule, Sub, Int64}
const MatchesBuf = Vector{Match}

import ..genrhsfun
import ..options
import ..@log

using .Schedulers

function inst_step(pat, sub::Sub, side::Symbol)
    # TODO interface istree (?)
    if haskey(sub, pat)
        (eclass, lit) = sub[pat]
        lit != nothing ? lit : eclass
        # if lit isa Symbol &&
        #     QuoteNode(lit)
        # end
    elseif pat isa Symbol
        error("unbound pattern variable $pat")
    elseif side == :right && pat isa QuoteNode && pat.value isa Symbol
        pat.value
    else
        pat
    end
end

function inst(pat, sub::Sub, side::Symbol)
    # remove type assertions
    if side == :left
        pat = remove_assertions(pat)
        pat = df_walk( x -> (isexpr(x, :(::)) ? x.args[1] : x), pat; skip_call=true )
    end

    f = df_walk(inst_step, pat, sub, side; skip_call=true)
    # println(f, " $side")
    f
end


"""
Core algorithm of the library: the equality saturation step.
"""
function eqsat_step!(egraph::EGraph, theory::Vector{Rule};
        scheduler=SimpleScheduler(), mod=@__MODULE__,
        match_hist=MatchesBuf(), sizeout=options[:sizeout], stopwhen=()->false,
        matchlimit=options[:matchlimit] # max number of matches
        )
    matches=MatchesBuf()
    EMPTY_DICT = Sub()
    report = Report(egraph)
    instcache = Dict{Rule, Dict{Sub, Int64}}()


    readstep!(scheduler)


    search_stats = @timed for rule ∈ theory
        # don't apply banned rules
        shouldskip(scheduler, rule) && continue

        if rule.mode ∉ [:rewrite, :dynamic, :equational]
            error("unsupported mode in rule ", rule)
        end

        # outermost symbol in lhs
        sym = gethead(rule.left)
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
            sym = gethead(rule.right)
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
        # mmm = Set(collect(mmm)[1:matchlimit])
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
            l = inst(rule.left, sub, :left)
            r = inst(rule.right, sub, :right)
            lc = addexpr!(egraph, l)
            rc = addexpr!(egraph, r)
            merge!(egraph, lc.id, rc.id)

            if rule.mode == :equational
                # swap
                r = inst(rule.left, sub, :right)
                l = inst(rule.right, sub, :left)
                lc = addexpr!(egraph, l)
                rc = addexpr!(egraph, r)
                merge!(egraph, lc.id, rc.id)
            end

        elseif rule.mode == :dynamic # execute the right hand!
            l = inst(rule.left, sub, :left)

            lc = addexpr!(egraph, l)

            (params, f) = rule.right_fun[mod]
            actual_params = map(params) do x
                (eclass, literal) = sub[x]
                literal != nothing ? literal : eclass
            end
            r = f(lc, egraph, actual_params...)
            rc = addexpr!(egraph, r)
            merge!(egraph,lc.id,rc.id)
        else
            error("unsupported rule mode")
        end

        # println(rule)
        # println(sub)
        # println(l); println(r)
        # display(egraph.M); println()
    end
    report.apply_stats = report.apply_stats + discard_value(apply_stats)

    union!(match_hist, mmm)

    # display(egraph.parents); println()
    # display(egraph.M); println()
    @label quit_rebuild
    report.saturated = isempty(egraph.dirty) && report.reason == nothing
    rebuild_stats = @timed rebuild!(egraph)
    report.rebuild_stats = report.rebuild_stats + discard_value(rebuild_stats)


    # TODO produce proofs with match_hist

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
    timeout=options[:timeout], stopwhen=(()->false), sizeout=options[:sizeout],
    matchlimit=options[:matchlimit],
    scheduler::Type{<:AbstractScheduler}=BackoffScheduler)

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

    # display(egraph.M); println()
    tot_report.iterations = curr_iter
    @log tot_report


    return tot_report
end
