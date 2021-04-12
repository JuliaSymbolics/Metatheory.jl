const Match = Tuple{Rule,Union{Nothing,Pattern},Sub,Int64}
const MatchesBuf = Vector{Match}

function cached_ids(g::EGraph, p::Pattern)# ::Vector{Int64}
    keys(g.classes)
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

    keys(g.classes)
    # cached
    # get(g.symcache, p.head, [])
end

# function cached_ids(g::EGraph, p::PatLiteral)
#     get(g.symcache, p.val, [])
# end

function search_rule!(g::EGraph, r::SymbolicRule, id::Int64)
    [(r, r.right, sub, id) for sub in ematch(g, r.left, id)] 
end

function search_rule!(g::EGraph, r::DynamicRule, id::Int64)
    [(r, nothing, sub, id) for sub in ematch(g, r.left, id)] 
end

function search_rule!(g::EGraph, r::BidirRule, id::Int64)
    vcat(
        [(r, r.right, sub, id) for sub in ematch(g, r.left, id)],
        [(r, r.left, sub, id) for sub in ematch(g, r.right, id)] 
    )
end


function search_rule!(g::EGraph, r::MultiPatRewriteRule)
    buf = ematch(g, r.left, id)
    if isempty(buf)
        return 
    end
    # TODO use ematchlist?
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
            # isempty(sub) && continue
            for i ∈ ids
                ematch(g, pat, i)
            end
        end
        buf = copy(newbuf)
    end
    for sub in buf
        # println("FINALLY ", sub, " $id")
        lock(mlock) do 
            push!(matches, (r, r.right, sub, id))
        end
    end
end


function eqsat_search_threaded!(egraph::EGraph, theory::Vector{<:Rule},
        scheduler::AbstractScheduler)::MatchesBuf
    matches = MatchesBuf()
    mlock = ReentrantLock()

    inequalities = filter(theory) do rule 
        rule isa UnequalRule
    end
    # never skip contradiction checks
    Threads.@threads for rule ∈ inequalities
        ids = cached_ids(egraph, rule.left)

        for id ∈ ids
            new_matches = search_rule!(egraph, rule, id)
            lock(mlock) do 
                matches = vcat(matches, new_matches)
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

        ids = cached_ids(egraph, rule.left)

        for id ∈ ids
            new_matches = search_rule!(egraph, rule, id)
            can_yield = inform!(scheduler, rule, new_matches)
            if can_yield 
                lock(mlock) do
                    matches = vcat(matches, new_matches)
                end
            end
        end
    end
    return matches
end


function eqsat_search!(egraph::EGraph, theory::Vector{<:Rule},
    scheduler::AbstractScheduler)::MatchesBuf
    matches = MatchesBuf()

    inequalities = filter(theory) do rule 
        rule isa UnequalRule
    end
# never skip contradiction checks
    for rule ∈ inequalities
        ids = cached_ids(egraph, rule.left)

        for id ∈ ids
            new_matches = search_rule!(egraph, rule, id)
            matches = vcat(matches, new_matches)
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

        ids = cached_ids(egraph, rule.left)

        for id ∈ ids
            new_matches = search_rule!(egraph, rule, id)
            # println(new_matches)
            can_yield = inform!(scheduler, rule, new_matches)
            if can_yield
                matches = vcat(matches, new_matches)
            end
        end
    end
    return matches
end
