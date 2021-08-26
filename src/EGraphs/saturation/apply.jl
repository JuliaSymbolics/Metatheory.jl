const UnionBuf = Vector{Tuple{EClassId, EClassId}}

function (rule::UnequalRule)(g::EGraph, match::Match)
    lc = match.id
    rinst = instantiate(g, match.pat_to_inst, match.sub, rule)
    rc, node = addexpr!(g, rinst)

    if find(g, lc) == find(g, rc)
        @log "Contradiction!" rule
        return (Contradiction(), nothing)
    end
    return (nothing, nothing)
end

function (rule::SymbolicRule)(g::EGraph, match::Match)
    rinst = instantiate(g, match.pat_to_inst, match.sub, rule)
    rc, node = addexpr!(g, rinst)
    return (nothing, (match.id, rc.id))
end


function (rule::DynamicRule)(g::EGraph, match::Match)
    f = rule.rhs_fun
    actual_params = [instantiate(g, PatVar(v, i), match.sub, rule) for (i, v) in enumerate(rule.patvars)]
    r = f(geteclass(g, match.id), match.sub, g, actual_params...)
    rc, node = addexpr!(g, r)

    return (nothing, (match.id, rc.id))
end


using .ReportReasons
function eqsat_apply!(g::EGraph, matches::MatchesBuf, rep::Report, params::SaturationParams)
    i = 0

    unions = UnionBuf()
    # println.(matches)
    for match ∈ matches
        i += 1

        # if i % 300 == 0
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


        rule=match.rule
        # println("applying $rule")
        # @show match.sub.sourcenode

        halt_reason, union = rule(g, match)
        if (halt_reason !== nothing)
            rep.reason = halt_reason
            return 
        end 
        (union !== nothing) && push!(unions, union)

        # println(rule)
        # println(sub)
        # println(l); println(r)
        # display(egraph.classes); println()
    end

    for (l,r) ∈ unions 
        merge!(g, l, r)
    end
end
