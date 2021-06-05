const UnionBuf = Vector{Tuple{EClassId, EClassId}}

function apply_rule!(g::EGraph, rule::UnequalRule,
        match::Match, matches::MatchesBuf, unions::UnionBuf,
        rep::Report, mod::Module)
    lc = match.id
    rinst = instantiate(g, match.pat_to_inst, match.sub, rule)
    # rc, node = addexpr!(g, rinst; proof_src=(rule => match.sub.sourcenode))
    rc, node = addexpr!(g, rinst)
    # addprooftrg!(match.sub.sourcenode, rule, node, g.age)
    # g.age += 1
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
    rinst = instantiate(g, match.pat_to_inst, match.sub, rule)

    rc, node = addexpr!(g, rinst)
    # rc, node = addexpr!(g, rinst; proof_src=(rule => match.sub.sourcenode))
    # addprooftrg!(match.sub.sourcenode, rule, node, g.age)
    # g.age += 1

    push!(unions, (match.id, rc.id))
    return (true, nothing)
end


function apply_rule!(g::EGraph, rule::DynamicRule, 
        match::Match, matches::MatchesBuf, unions::UnionBuf,
        rep::Report,  mod::Module)
    f = Rules.getrhsfun(rule, mod)
    actual_params = [instantiate(g, PatVar(v, i), match.sub, rule) for (i, v) in enumerate(rule.patvars)]
    r = f(geteclass(g, match.id), match.sub, g, actual_params...)
    rc, node = addexpr!(g, r)
    # rc, node = addexpr!(g, r; proof_src=(rule => match.sub.sourcenode))
    # addprooftrg!(match.sub.sourcenode, rule, node, g.age)
    # g.age += 1

    push!(unions, (match.id, rc.id))
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


        rule=match.rule
        # println("applying $rule")
        # @show match.sub.sourcenode

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
