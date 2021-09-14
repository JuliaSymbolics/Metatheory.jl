function (rule::UnequalRule)(g::EGraph, match::Match)
    lc = match.id
    rinst = instantiate(g, match.pat_to_inst, match.sub, rule)
    rc, node = addexpr!(g, rinst)

    if find(g, lc) == find(g, rc)
        @log "Contradiction!" rule
        return Contradiction()
    end
    return nothing
end

function (rule::SymbolicRule)(g::EGraph, match::Match)
    rinst = instantiate(g, match.pat_to_inst, match.sub, rule)
    rc, node = addexpr!(g, rinst)
    merge!(g, match.id, rc.id)
    return nothing
end


function (rule::DynamicRule)(g::EGraph, match::Match)
    f = rule.rhs_fun
    actual_params = [instantiate(g, PatVar(v, i, alwaystrue), match.sub, rule) for (i, v) in enumerate(rule.patvars)]
    r = f(geteclass(g, match.id), match.sub, g, actual_params...)
    rc, node = addexpr!(g, r)
    merge!(g, match.id, rc.id)
    return nothing
end


using .ReportReasons
function eqsat_apply!(g::EGraph, matches, rep::Report, params::SaturationParams)
    i = 0
    # println.(matches)
    for match ∈ matches
        i += 1

        if params.eclasslimit > 0 && g.numclasses > params.eclasslimit
            @log "E-GRAPH SIZEOUT"
            rep.reason = EClassLimit(params.eclasslimit)
            return
        end

        if reached(g, params.goal)
            @log "Goal reached"
            rep.reason = GoalReached()
            return
        end


        rule = match.rule
        # println("applying $rule")

        halt_reason = rule(g, match)
        if (halt_reason !== nothing)
            rep.reason = halt_reason
            return 
        end 

        # println(rule)
        # println(sub)
        # println(l); println(r)
        # display(egraph.classes); println()
    end
end
