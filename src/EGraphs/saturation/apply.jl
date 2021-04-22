const UnionBuf = Vector{Tuple{Int64, Int64}}

function apply_rule!(g::EGraph, rule::UnequalRule,
        match::Match, matches::MatchesBuf, unions::UnionBuf,
        rep::Report, mod::Module)
    (_, pat, sub, id) = match
    lc = id
    rinst = instantiate(g, pat, sub, rule)
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
        match::Match, matches::MatchesBuf, unions::UnionBuf, 
        rep::Report,  mod::Module)
    (_, pat, sub, id) = match
    # println(sub)
    rinst = instantiate(g, pat, sub, rule)
    rc = addexpr!(g, rinst)
    push!(unions, (id, rc.id))
    return (true, nothing)
end


function apply_rule!(g::EGraph, rule::DynamicRule, 
        match::Match, matches::MatchesBuf, unions::UnionBuf,
        rep::Report,  mod::Module)
    (_, pat, sub, id) = match
    f = Rules.getrhsfun(rule, mod)
    actual_params = [instantiate(g, PatVar(v, i), sub, rule) for (i, v) in enumerate(rule.patvars)]
    r = f(geteclass(g, id), g, actual_params...)
    rc = addexpr!(g, r)

    push!(unions, (id, rc.id))
    return (true, nothing)
end


using .ReportReasons
function eqsat_apply!(g::EGraph, matches::MatchesBuf,
        rep::Report, mod::Module, params::SaturationParams)::Report
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


        rule=match[1]
        # println("applied $rule")

        (ok, nrep) = apply_rule!(g, rule, match, matches, unions, rep, mod)
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
