const Match = Tuple{Rule, Sub}
const MatchesBuf = Vector{Match}
# const MatchesBuf = Dict{Rule,Set{Sub}}

import ..genrhsfun
import ..options
import ..@log

using .Schedulers

# using Memoize

function inst_step(pat, sub::Sub, side::Symbol)
    if pat isa Expr
        start = isexpr(pat, :call) ? 2 : 1
        pat.args[start:end] = pat.args[start:end] .|> x ->
            inst_step(x, sub, side)
            return pat
    end

    if haskey(sub, pat)
        (eclass, lit) = sub[pat]
        lit != nothing ? lit : eclass
    elseif pat isa Symbol
        error("unbound pattern variable $pat")
    elseif side == :right && pat isa QuoteNode && pat.value isa Symbol
        pat.value
    else
        pat
    end
end

# @memoize ???
function inst(pat, sub::Sub, side::Symbol)
    # remove type assertions
    if side == :left
        pat = remove_assertions(pat)
    end

    expr = deepcopy(pat)
    inst_step(expr, sub, side)
    # df_walk(inst_step, pat, sub, side; skip_call=true)
end

"""
Exactly like [`addexpr!`](@ref), but instantiate pattern variables
from a substitution, resulting from a pattern matcher run.
"""
function addexprinst_rec!(G::EGraph, pat, sub::Sub, side::Symbol)::EClass
    # e = preprocess(pat)
    # println("========== $pat ===========")

    pat isa EClass && return pat

    if haskey(sub, pat)
        (eclass, lit) = sub[pat]
        pat = (lit != nothing ? lit : eclass)
    elseif pat isa Symbol
        error("unbound pattern variable $pat")
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
            c_eclass = addexprinst_rec!(G, child, sub, side)
            @inbounds class_ids[i] = c_eclass.id
        end
        node = ENode(pat, class_ids)
        return add!(G, node)
    end

    return add!(G, ENode(pat))

    # println("node $node")

end

# addexprinst_rec!(g::EGraph, e::EClass, sub::Sub, side::Symbol)::EClass = (println("matched eclass $e"); e)

addexprinst!(g::EGraph, e, sub::Sub, side::Symbol)::EClass =
    addexprinst_rec!(g, preprocess(e), sub, side)

# @memoize

function cached_ids(egraph::EGraph, side)::Vector{Int64}
    # outermost symbol in rule side
    if istree(side)
        sym = gethead(side)
        get(egraph.symcache, sym, [])
    else
        collect(keys(egraph.M))
    end
end

function eqsat_search!(egraph::EGraph, theory::Vector{Rule},
        scheduler::AbstractScheduler)::MatchesBuf
    matches=MatchesBuf()
    for rule ∈ theory
        # don't apply banned rules
        shouldskip(scheduler, rule) && continue

        if rule.mode ∉ [:rewrite, :dynamic, :equational]
            error("unsupported mode in rule ", rule)
        end

        ids = cached_ids(egraph, rule.left)

        for id ∈ ids
            for sub in ematch(egraph, rule.left, id)
                # display(sub); println()
                !isempty(sub) && push!(matches, (rule, sub))
            end
        end

        if rule.mode == :equational
            ids = cached_ids(egraph, rule.right)
            for id ∈ ids
                for sub in ematch(egraph, rule.right, id)
                    # display(sub); println()
                    !isempty(sub) && push!(matches, (rule, sub))
                end
            end
        end
    end
    return matches
end

function eqsat_apply!(egraph::EGraph, matches::MatchesBuf,
        scheduler::AbstractScheduler, report::Report,
        mod::Module, sizeout::Int64, stopwhen::Function)::Report
    i = 0
    for (rule, sub) ∈ matches
        i += 1

        if i % 300 == 0
            if sizeout > 0 && length(egraph.U) > sizeout
                @log "E-GRAPH SIZEOUT"
                report.reason = :sizeout
                return report
            end

            if stopwhen()
                @log "Halting requirement satisfied"
                report.reason = :condition
                return report
            end
        end

        writestep!(scheduler, rule)

        if rule.mode == :rewrite || rule.mode == :equational # symbolic replacement
            # l = inst(rule.left, sub, :left)
            # r = inst(rule.right, sub, :right)
            l = remove_assertions(rule.left)
            r = rule.right
            # r = unquote_sym(rule.right)
            # println(l); println(r)
            lc = addexprinst!(egraph, l, sub, :left)
            rc = addexprinst!(egraph, r, sub, :right)
            # lc = addexpr!(egraph, l)
            # rc = addexpr!(egraph, r)
            merge!(egraph, lc.id, rc.id)

            if rule.mode == :equational
                # swap
                # r = inst(rule.left, sub, :right)
                # l = inst(rule.right, sub, :left)
                # r = unquote_sym(rule.left)
                r = rule.left
                l = remove_assertions(rule.right)
                # lc = addexpr!(egraph, l)
                # rc = addexpr!(egraph, r)
                lc = addexprinst!(egraph, l, sub, :left)
                rc = addexprinst!(egraph, r, sub, :right)
                merge!(egraph, lc.id, rc.id)
            end

        elseif rule.mode == :dynamic # execute the right hand!
            # l = inst(rule.left, sub, :left)
            # lc = addexpr!(egraph, l)
            l = remove_assertions(rule.left)
            lc = addexprinst!(egraph, l, sub, :left)

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
    return report
end

"""
Core algorithm of the library: the equality saturation step.
"""
function eqsat_step!(egraph::EGraph, theory::Vector{Rule};
        scheduler=SimpleScheduler(), mod=@__MODULE__,
        match_hist=MatchesBuf(), sizeout=options[:sizeout], stopwhen=()->false,
        matchlimit=options[:matchlimit] # max number of matches
        )

    report = Report(egraph)
    instcache = Dict{Rule, Dict{Sub, Int64}}()


    readstep!(scheduler)


    search_stats = @timed eqsat_search!(egraph, theory, scheduler)
    matches = search_stats.value
    report.search_stats = report.search_stats + discard_value(search_stats)

    # mmm = unique(matches)
    # mmm = symdiff(match_hist, matches)

    matches = setdiff(matches, match_hist)
    # for (rule, subset) ∈ matches
    #     setdiff!(subset, match_hist[rule])
    # end

    # println("============ WRITE PHASE ============")
    # println("\n $(length(matches)) $(length(match_hist))")
    if length(matches) > matchlimit
        matches = matches[1:matchlimit]
    #     # mmm = Set(collect(mmm)[1:matchlimit])
    #     #
    #     # report.reason = :matchlimit
    #     # @goto quit_rebuild
    end
    # println(" diff length $(length(matches))")

    apply_stats = @timed eqsat_apply!(egraph, matches,
        scheduler, report, mod, sizeout, stopwhen)
    report = apply_stats.value
    report.apply_stats = report.apply_stats + discard_value(apply_stats)

    # for (rule, subset) ∈ matches
    #     union!(match_hist[rule], subset)
    # end
    union!(match_hist, matches)

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
    scheduler::Type{<:AbstractScheduler}=BackoffScheduler,  schedulerparams::Tuple=())

    curr_iter = 0

    # prepare the dynamic rules in this module
    for rule ∈ theory
        if rule.mode == :dynamic && !haskey(rule.right_fun, mod)
            rule.right_fun[mod] = genrhsfun(rule.left, rule.right, mod)
        end
    end

    # init the scheduler
    sched = scheduler(egraph, theory, schedulerparams...)

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
