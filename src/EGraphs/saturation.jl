const Match = Tuple{Rule, Sub, Int64, Bool} #bool isright
const MatchesBuf = OrderedSet{Match}
# const MatchesBuf = Dict{Rule,Set{Sub}}

import ..genrhsfun
import ..options
import ..@log

using .Schedulers

"""
Exactly like [`addexpr!`](@ref), but instantiate pattern variables
from a substitution, resulting from a pattern matcher run.
"""
function addexprinst_rec!(G::EGraph, pat, sub::Sub, side::Symbol, r::Rule)::EClass
    # e = preprocess(pat)
    # println("========== $pat ===========")

    pat isa EClass && return pat

    if haskey(sub, pat)
        (eclass, lit) = sub[pat]
        pat = (lit !== nothing ? lit : eclass)
    elseif pat isa Symbol
        # TODO tell me the rule!
        # for (k,v) ∈ sub
        #     println("$k => $v"); println()
        # end
        # println.(sort(collect(G.emap); lt=((x,y)-> x[1] < y[1])))
        error("unbound pattern variable $pat in rule $r")
    elseif side == :right && pat isa QuoteNode && pat.value isa Symbol
        pat = pat.value
    end

    # println("pat $pat")
    pat isa EClass && return pat

    if istree(pat)
        args = getargs(pat)
        n = length(args)
        class_ids = Vector{Int64}(undef, length(args))
        for i ∈ 1:n
            # println("child $child")
            @inbounds child = args[i]
            c_eclass = addexprinst_rec!(G, child, sub, side, r)
            @inbounds class_ids[i] = c_eclass.id
        end
        node = ENode(pat, class_ids)
        return add!(G, node)
    end

    return add!(G, ENode(pat))
end

addexprinst!(g::EGraph, e, sub::Sub, side::Symbol, r::Rule)::EClass =
    addexprinst_rec!(g, preprocess(e), sub, side, r)


function cached_ids(egraph::EGraph, side)#::Vector{Int64}
    # outermost symbol in rule side
    # side = remove_assertions(side)
    # side = unquote_sym(side)
    if istree(side)
        sym = gethead(side)
        get(egraph.symcache, sym, [])
    else
        # collect(keys(egraph.emap))
        keys(egraph.emap)
    end
end

function eqsat_search!(egraph::EGraph, theory::Vector{Rule},
        scheduler::AbstractScheduler)::MatchesBuf
    matches=MatchesBuf()
    for rule ∈ theory
        # don't apply banned rules
        if shouldskip(scheduler, rule)
            # println("skipping banned rule $rule")
            continue
        end
        if rule.mode ∉ [:symbolic, :dynamic, :equational, :unequal]
            error("unsupported mode in rule ", rule)
        end

        ids = cached_ids(egraph, rule.left)

        for id ∈ ids
            for sub in ematch(egraph, rule.left, id)
                # display(sub); println()
                !isempty(sub) && push!(matches, (rule, sub, id, false))
            end
        end

        if rule.mode == :equational || rule.mode == :unequal
            ids = cached_ids(egraph, rule.right)
            for id ∈ ids
                for sub in ematch(egraph, rule.right, id)
                    # display(sub); println()
                    !isempty(sub) && push!(matches, (rule, sub, id, true))
                end
            end
        end
    end
    return matches
end

function eqsat_apply!(egraph::EGraph, matches::MatchesBuf,
        scheduler::AbstractScheduler, report::Report,
        mod::Module, params::SaturationParams)::Report
    i = 0
    for match ∈ matches
        (rule, sub, id, isright) = match
        i += 1

        if i % 300 == 0
            if params.sizeout > 0 && length(egraph.uf) > params.sizeout
                @log "E-GRAPH SIZEOUT"
                report.reason = :sizeout
                return report
            end

            if params.stopwhen()
                @log "Halting requirement satisfied"
                report.reason = :condition
                return report
            end
        end

        writestep!(scheduler, rule)


        if rule.mode == :symbolic || rule.mode == :equational || rule.mode == :unequal # symbolic replacement
            if isright
                rc = id
                # println("THE ONE IT MATCHED ON = ", rc)
                # schifo = addexprinst!(egraph, rule.right, sub, :right).id
                # println("THE INSTANTIATED ONE = ", schifo)
                lc = addexprinst!(egraph, remove_assertions(rule.left), sub, :left, rule).id
            else
                lc = id
                # println("THE ONE IT MATCHED ON = ", lc)
                # schifo = addexprinst!(egraph, remove_assertions(rule.left), sub, :left).id
                # println("THE INSTANTIATED ONE = ", schifo)
                rc = addexprinst!(egraph, rule.right, sub, :right, rule).id
            end
            if rule.mode == :unequal
                delete!(matches, match)
                if find(egraph, lc) == find(egraph, rc)
                    @log "Contradiction!" rule
                    report.reason = :contradiction
                    return report
                end
            else
                merge!(egraph, lc, rc)
            end
        elseif rule.mode == :dynamic # execute the right hand!
            lc = id
            f = getrhsfun(rule, mod)
            actual_params = map(rule.patvars) do x
                (eclass, literal) = sub[x]
                literal !== nothing ? literal : eclass
            end
            r = f(geteclass(egraph, lc), egraph, actual_params...)
            rc = addexpr!(egraph, r)
            merge!(egraph,lc,rc.id)
        else
            error("unsupported rule mode")
        end

        # println(rule)
        # println(sub)
        # println(l); println(r)
        # display(egraph.emap); println()
    end
    return report
end

"""
Core algorithm of the library: the equality saturation step.
"""
function eqsat_step!(egraph::EGraph, theory::Vector{Rule}, mod::Module,
        scheduler::AbstractScheduler, match_hist::MatchesBuf, params::SaturationParams)

    report = Report(egraph)
    instcache = Dict{Rule, Dict{Sub, Int64}}()

    readstep!(scheduler)


    search_stats = @timed eqsat_search!(egraph, theory, scheduler)
    matches = search_stats.value
    report.search_stats = report.search_stats + discard_value(search_stats)

    # mmm = unique(matches)
    # mmm = symdiff(match_hist, matches)

    matches = setdiff!(matches, match_hist)
    # for (rule, subset) ∈ matches
    #     setdiff!(subset, match_hist[rule])
    # end

    # println("============ WRITE PHASE ============")
    # println("\n $(length(matches)) $(length(match_hist))")
    # if length(matches) > matchlimit
    #     matches = matches[1:matchlimit]
    # #     # mmm = Set(collect(mmm)[1:matchlimit])
    # #     #
    # #     # report.reason = :matchlimit
    # #     # @goto quit_rebuild
    # end
    # println(" diff length $(length(matches))")

    apply_stats = @timed eqsat_apply!(egraph, matches, scheduler, report, mod, params)
    report = apply_stats.value
    report.apply_stats = report.apply_stats + discard_value(apply_stats)

    # don't add inequalities to history
    union!(match_hist, matches)

    # display(egraph.parents); println()
    # display(egraph.emap); println()
    @label quit_rebuild
    report.saturated = isempty(egraph.dirty) && report.reason === nothing
    rebuild_stats = @timed rebuild!(egraph)
    report.rebuild_stats = report.rebuild_stats + discard_value(rebuild_stats)

    # TODO produce proofs with match_hist
    total_time!(report)

    return report, egraph
end

"""
Given an [`EGraph`](@ref) and a collection of rewrite rules,
execute the equality saturation algorithm.
"""
saturate!(egraph::EGraph, theory::Vector{Rule}; mod=@__MODULE__) =
    saturate!(egraph, theory, SaturationParams(); mod=mod)

function saturate!(egraph::EGraph, theory::Vector{Rule}, params::SaturationParams;
    mod=@__MODULE__,)

    curr_iter = 0

    # init the scheduler
    sched = params.scheduler(egraph, theory, params.schedulerparams...)

    match_hist = MatchesBuf()

    tot_report = Report()

    # GC.enable(false)
    while true
        curr_iter+=1

        options[:printiter] && @info("iteration ", curr_iter)

        report, egraph = eqsat_step!(egraph, theory, mod, sched, match_hist, params)

        tot_report = tot_report + report

        # report.reason == :matchlimit && break
        report.reason == :condition && break
        report.reason == :contradiction && break
        cansaturate(sched) && report.saturated && (tot_report.saturated = true; break)
        curr_iter >= params.timeout && (tot_report.reason = :timeout; break)
        params.sizeout > 0 && length(egraph.uf) > params.sizeout && (tot_report.reason = :sizeout; break)
        params.stopwhen() && (tot_report.reason = :condition; break)
    end
    # println(match_hist)

    # display(egraph.emap); println()
    tot_report.iterations = curr_iter
    @log tot_report
    # GC.enable(true)

    return tot_report
end
