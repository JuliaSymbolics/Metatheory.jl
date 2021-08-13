const UnionBuf = Vector{Tuple{EClassId, EClassId}}

function apply_rule!(g::EGraph, rule::UnequalRule,
        match::Match, unions::UnionBuf,
        rep::Report)
    lc = match.id
    rinst = instantiate(g, match.pat_to_inst, match.sub, rule)
    rc, node = addexpr!(g, rinst; callcheck=false)

    if find(g, lc) == find(g, rc)
        @log "Contradiction!" rule
        rep.reason = Contradiction()
        return (false, rep)
    end
    return (true, nothing)
end

function apply_rule!(g::EGraph, rule::SymbolicRule, 
        match::Match, unions::UnionBuf, 
        rep::Report)
    rinst = instantiate(g, match.pat_to_inst, match.sub, rule)

    rc, node = addexpr!(g, rinst; callcheck=false)

    push!(unions, (match.id, rc.id))
    return (true, nothing)
end


function apply_rule!(g::EGraph, rule::DynamicRule, 
        match::Match, unions::UnionBuf,
        rep::Report)
    f = rule.rhs_fun
    actual_params = [instantiate(g, PatVar(v, i), match.sub, rule) for (i, v) in enumerate(rule.patvars)]
    r = f(geteclass(g, match.id), match.sub, g, actual_params...)
    rc, node = addexpr!(g, r; callcheck=false)

    push!(unions, (match.id, rc.id))
    return (true, nothing)
end


using .ReportReasons
function eqsat_apply!(g::EGraph, matches::MatchesBuf,
        rep::Report, params::SaturationParams)::Report
    i = 0

    unions = UnionBuf()
    # println.(matches)
    for match ∈ matches
        i += 1

        # if i % 300 == 0
        if params.eclasslimit > 0 && g.numclasses > params.eclasslimit
            @log "E-GRAPH SIZEOUT"
            rep.reason = EClassLimit(params.eclasslimit)
            return rep
        end

        if reached(g, params.goal)
            @log "Goal reached"
            rep.reason = GoalReached()
            return rep
        end


        rule=match.rule
        # println("applying $rule")
        # @show match.sub.sourcenode

        (ok, nrep) = apply_rule!(g, rule, match, unions, rep)
        if !ok 
            return nrep 
        end
        # println(rule)
        # println(sub)
        # println(l); println(r)
        # display(egraph.classes); println()
    end

    for (l,r) ∈ unions 
        merge!(g, l, r)
    end
    
    return rep
end
