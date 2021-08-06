struct Match
    rule::AbstractRule 
    # the rhs pattern to instantiate 
    pat_to_inst::Union{Nothing,Pattern}
    # the substitution
    sub::Sub 
    # the id the matched the lhs  
    id::EClassId
end

const MatchesBuf = Vector{Match}

function cached_ids(g::EGraph, p::Pattern)# ::Vector{Int64}
    collect(keys(g.classes))
end

# FIXME 
function cached_ids(g::EGraph, p::PatTerm)
    # println("pattern $p, $(p.head)")
    # println("all ids")
    # keys(g.classes) |> println
    # println("cached symbols")
    # cached = get(g.symcache, p.head, Set{Int64}())
    # println("symbols where $(p.head) appears")
    # appears = Set{Int64}() 
    # for (id, class) ∈ g.classes 
    #     for n ∈ class 
    #         if n.head == p.head
    #             push!(appears, id) 
    #         end
    #     end
    # end
    # # println(appears)
    # if !(cached == appears)
    #     @show cached 
    #     @show appears
    # end

    collect(keys(g.classes))
    # cached
    # get(g.symcache, p.head, [])
end

# function cached_ids(g::EGraph, p::PatLiteral)
#     get(g.symcache, p.val, [])
# end

# function (r::SymbolicRule)(g::EGraph, id)
#     ematch(g, r.ematch_program, id) .|> sub -> Match(r, r.right, sub, id)
# end

# function (r::DynamicRule)(g::EGraph, id)
#     ematch(g, r.ematch_program, id) .|> sub -> Match(r, nothing, sub, id)
# end

# function (r::BidirRule)(g::EGraph, id)
#     vcat(ematch(g, r.ematch_program_l, id) .|> sub -> Match(r, r.right, sub, id),
#         ematch(g, r.ematch_program_r, id) .|> sub -> Match(r, r.left, sub, id))
# end

function (r::SymbolicRule)(g::EGraph, id)
    if !isassigned(r.staged_ematch_fun)
        expr = stage(r.ematch_program)
        r.staged_ematch_fun[] = closure_generator(@__MODULE__, expr)         
    end
    r.staged_ematch_fun[](g, id) .|> sub -> Match(r, r.right, sub, id)
end

function (r::DynamicRule)(g::EGraph, id)
    if !isassigned(r.staged_ematch_fun)
        expr = stage(r.ematch_program)
        r.staged_ematch_fun[] = closure_generator(@__MODULE__, expr)         
    end
    r.staged_ematch_fun[](g, id) .|> sub -> Match(r, nothing, sub, id)
end

function (r::BidirRule)(g::EGraph, id)
    if !isassigned(r.staged_ematch_fun_l)
        expr = stage(r.ematch_program_l)
        r.staged_ematch_fun_l[] = closure_generator(@__MODULE__, expr)         
    end
    if !isassigned(r.staged_ematch_fun_r)
        expr = stage(r.ematch_program_r)
        r.staged_ematch_fun_r[] = closure_generator(@__MODULE__, expr)         
    end
    vcat(r.staged_ematch_fun_l[](g, id) .|> sub -> Match(r, r.right, sub, id),
        r.staged_ematch_fun_r[](g, id) .|> sub -> Match(r, r.left, sub, id))
end

function eqsat_search_threaded!(egraph::EGraph, theory::Vector{<:AbstractRule},
        scheduler::AbstractScheduler)::MatchesBuf
    matches = MatchesBuf()
    mlock = ReentrantLock()

    inequalities = filter(Base.Fix2(isa, UnequalRule), theory)
    # never skip contradiction checks
    Threads.@threads for rule ∈ inequalities
        ids = cached_ids(egraph, rule.left)

        lock(mlock) do 
            for id in ids 
                append!(matches, rule(egraph, id))
            end
        end 
    end

    other_rules = filter(theory) do rule 
        !(rule isa UnequalRule)
    end
    Threads.@threads for rule ∈ other_rules
        # don't apply banned rules
        if !cansearch(scheduler, rule)
            # println("skipping banned rule $rule")
            continue
        end

        rule_matches = []
        ids = cached_ids(egraph, rule.left)
        for id in ids 
            append!(rule_matches, rule(egraph, id))
        end

        can_yield = inform!(scheduler, rule, rule_matches)
        if can_yield 
            lock(mlock) do
                append!(matches, rule_matches)
            end
        end
    end
    return matches
end


function eqsat_search!(egraph::EGraph, theory::Vector{<:AbstractRule},
    scheduler::AbstractScheduler)::MatchesBuf
    matches = MatchesBuf()

    inequalities = filter(Base.Fix2(isa, UnequalRule), theory)
    # never skip contradiction checks
    for rule ∈ inequalities
        ids = cached_ids(egraph, rule.left)

        for id in ids 
            append!(matches, rule(egraph, id))
        end
    end

    other_rules = filter(theory) do rule 
        !(rule isa UnequalRule)
    end
    for rule ∈ other_rules
    # don't apply banned rules
        if !cansearch(scheduler, rule)
        # println("skipping banned rule $rule")
            continue
        end

        rule_matches = Match[]
        ids = cached_ids(egraph, rule.left)
        for id in ids 
            append!(rule_matches, rule(egraph, id))
        end
        can_yield = inform!(scheduler, rule, rule_matches)
        if can_yield
            append!(matches, rule_matches)
        end
    end
    return matches
end
