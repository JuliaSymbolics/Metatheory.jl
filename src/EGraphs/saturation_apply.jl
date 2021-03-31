
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
    rc = addexpr!(g, rinst)
    if canprune(typeof(rule)) && rule.prune 
        prune!(g, id, rc)
    else
        merge!(g, id, rc.id)
    end
    return (true, nothing)
end


function apply_rule!(g::EGraph, rule::DynamicRule, 
        match::Match, matches::MatchesBuf, rep::Report,  mod::Module)
    (_, pat, sub, id) = match
    f = Rules.getrhsfun(rule, mod)
    actual_params = [instantiate(x, sub, rule) for x in rule.patvars]
    r = f(geteclass(g, id), g, actual_params...)
    rc = addexpr!(g, r)

    if canprune(typeof(rule)) && rule.prune 
        prune!(g, id, rc)
    else
        merge!(g, id, rc.id)
    end
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

        if params.stopwhen()
            @log "Halting requirement satisfied"
            rep.reason = ConditionSatisfied()
            return rep
        end


        rule=match[1]
        # println("applied $rule")
        writestep!(scheduler, rule)
        if find(g, match[4]) ∈ g.pruned
            return rep
        end
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
