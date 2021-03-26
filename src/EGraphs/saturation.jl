const Match = Tuple{Rule, Union{Nothing, Pattern}, Sub, Int64}
const MatchesBuf = Vector{Match}
# const MatchesBuf = Dict{Rule,Set{Sub}}

import ..genrhsfun
import ..options
import ..@log

using .Schedulers


function instantiate(pat::PatVar, sub::Sub, rule::Rule)
    if haskey(sub, pat)
        (eclass, lit) = sub[pat]
        return (lit !== nothing ? lit : eclass)
    else
        error("unbound pattern variable $pat in rule $rule")
    end
end

function instantiate(pat::PatLiteral, sub::Sub, rule::Rule)
    pat.val
end

function instantiate(pat::PatTypeAssertion, sub::Sub, rule::Rule)
    instantiate(pat.var, sub, rule)
end

function instantiate(pat::PatTerm, sub::Sub, rule::Rule)
    # TODO support custom types here!
    # similarterm ? ask Shashi
    meta = pat.metadata
    if meta !== nothing && meta.iscall
        Expr(:call, pat.head, map(x -> instantiate(x, sub, rule), pat.args)...)
    else
        Expr(pat.head, map(x -> instantiate(x, sub, rule), pat.args)...)
    end
end


function cached_ids(g::EGraph, p::Pattern)#::Vector{Int64}
    keys(g.classes)
end

# FIXME 
# function cached_ids(g::EGraph, p::PatTerm)
#     get(g.symcache, p.head, [])
# end

# function cached_ids(g::EGraph, p::PatLiteral)
#     get(g.symcache, p.val, [])
# end

function search_rule!(g::EGraph, r::SymbolicRule, id::Int64, matches::MatchesBuf)
    for sub in ematch(g, r.left, id)
        isempty(sub) && error("empty sub")
        push!(matches, (r, r.right, sub, id))
    end
end

function search_rule!(g::EGraph, r::DynamicRule, id::Int64, matches::MatchesBuf)
    for sub in ematch(g, r.left, id)
        isempty(sub) && error("empty sub")
        push!(matches, (r, nothing, sub, id))
    end
end

function search_rule!(g::EGraph, r::BidirRule, id::Int64, matches::MatchesBuf)
    for sub in ematch(g, r.left, id)
        isempty(sub) && error("empty sub")
        push!(matches, (r, r.right, sub, id))
    end
    for sub in ematch(g, r.right, id)
        isempty(sub) && error("empty sub")
        push!(matches, (r, r.left, sub, id))
    end
end

function Base.show(io::IO, s::Sub)
    print(io, "Sub[")
    kvs = collect(s)
    n = length(kvs)
    for i ∈ 1:n
        print(io, kvs[i][1], " => ", kvs[i][2][1].id)
        if i < n 
            print(io, ",")
        end
    end
    print(io, "]")
end

function search_rule!(g::EGraph, r::MultiPatRewriteRule, id::Int64, matches::MatchesBuf)
    buf = ematch(g, r.left, id)
    if isempty(buf)
        return 
    end
    pats_todo = reverse(copy(r.pats))
    while !isempty(pats_todo)
        pat = pop!(pats_todo)
        # println("====================")
        # @show pat
        ids = cached_ids(g, pat)
        newbuf = SubBuf()
        while !isempty(buf)
            sub = pop!(buf)
            # @show sub
            isempty(sub) && continue
            for i ∈ ids
                ematch(g, pat, i; sub=sub, buf=newbuf)
            end
        end
        buf = copy(newbuf)
    end
    for sub in buf
        # println("FINALLY ", sub, " $id")
        push!(matches, (r, r.right, sub, id))
    end
end


function eqsat_search!(egraph::EGraph, theory::Vector{<:Rule},
        scheduler::AbstractScheduler)::MatchesBuf
    matches=MatchesBuf()
    for rule ∈ theory
        # don't apply banned rules
        if shouldskip(scheduler, rule)
            # println("skipping banned rule $rule")
            continue
        end

        ids = cached_ids(egraph, rule.left)

        for id ∈ ids
            search_rule!(egraph, rule, id, matches)
        end
    end
    return matches
end

function apply_rule!(g::EGraph, rule::UnequalRule,
        match::Match, matches::MatchesBuf, rep::Report, mod::Module)
    (_, pat, sub, id) = match
    lc = id
    rinst = instantiate(pat, sub, rule)
    rc = addexpr!(g, rinst).id
    # delete!(matches, match)
    if find(g, lc) == find(g, rc)
        @log "Contradiction!" rule
        rep.reason = Contradiction()
        return (false, rep)
    end
    return (true, nothing)
end

function apply_rule!(g::EGraph, rule::SymbolicRule, 
        match::Match, matches::MatchesBuf, rep::Report,  mod::Module)
    (_, pat, sub, id) = match
    rinst = instantiate(pat, sub, rule)
    rc = addexpr!(g, rinst).id
    merge!(g, id, rc)
    return (true, nothing)
end

function apply_rule!(g::EGraph, rule::DynamicRule, 
        match::Match, matches::MatchesBuf, rep::Report,  mod::Module)
    (_, pat, sub, id) = match
    lc = id
    f = Rules.getrhsfun(rule, mod)
    actual_params = map(rule.patvars) do x
        (eclass, literal) = sub[x]
        literal !== nothing ? literal : eclass
    end
    r = f(geteclass(g, lc), g, actual_params...)
    rc = addexpr!(g, r)
    merge!(g,lc,rc.id)
    return (true, nothing)
end


using .ReportReasons
function eqsat_apply!(g::EGraph, matches::MatchesBuf,
        scheduler::AbstractScheduler, rep::Report,
        mod::Module, params::SaturationParams)::Report
    i = 0
    for match ∈ matches
        i += 1

        # if i % 300 == 0
        if params.eclasslimit > 0 && g.numclasses > params.eclasslimit
            @log "E-GRAPH SIZEOUT"
            rep.reason = EClassLimit(params.eclasslimit)
            return rep
        end

        #     if params.stopwhen()
        #         @log "Halting requirement satisfied"
        #         rep.reason = ConditionSatisfied()
        #         return rep
        #     end
        # end

        rule=match[1]
        writestep!(scheduler, rule)
        (ok, nrep) = apply_rule!(g, rule, match, matches, rep, mod)
        if !ok 
            return nrep 
        end
        # println(rule)
        # println(sub)
        # println(l); println(r)
        # display(egraph.classes); println()
    end
    return rep
end

"""
Core algorithm of the library: the equality saturation step.
"""
function eqsat_step!(g::EGraph, theory::Vector{<:Rule}, mod::Module,
        scheduler::AbstractScheduler, match_hist::MatchesBuf, params::SaturationParams)

    report = Report(g)
    instcache = Dict{Rule, Dict{Sub, Int64}}()

    readstep!(scheduler)


    search_stats = @timed eqsat_search!(g, theory, scheduler)
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
        if report.reason isa Union{ConditionSatisfied, Contradiction, Saturated}
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
