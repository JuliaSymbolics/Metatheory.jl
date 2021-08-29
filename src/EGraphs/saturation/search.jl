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

function (r::SymbolicRule)(g::EGraph, id::EClassId)
    ematch(g, r.ematch_program, id) .|> sub -> Match(r, r.right, sub, id)
end

function (r::DynamicRule)(g::EGraph, id::EClassId)
    ematch(g, r.ematch_program, id) .|> sub -> Match(r, nothing, sub, id)
end

function (r::BidirRule)(g::EGraph, id::EClassId)
    vcat(ematch(g, r.ematch_program_l, id) .|> sub -> Match(r, r.right, sub, id),
        ematch(g, r.ematch_program_r, id) .|> sub -> Match(r, r.left, sub, id))
end


macro maybethreaded(x, body)
    esc(quote 
        if $x
            Threads.@threads $body
        else 
            $body
        end
    end)
end

function eqsat_search!(egraph::EGraph, theory::Vector{<:AbstractRule},
    scheduler::AbstractScheduler, report; 
    threaded=false, timer_tree_point=["Search"])::MatchesBuf
    matches = MatchesBuf()
    mlock = ReentrantLock()


    inequalities = filter(Base.Fix2(isa, UnequalRule), theory)
    # never skip contradiction checks
    @maybethreaded threaded for rule ∈ inequalities
        to = TimerOutput()
        @timeit to repr(rule) begin
            ids = cached_ids(egraph, rule.left)

            lock(mlock) do 
                for id in ids 
                    append!(matches, rule(egraph, id))
                end
            end
        end
        merge!(report.to, to, tree_point=timer_tree_point)
    end

    other_rules = filter(theory) do rule 
        !(rule isa UnequalRule)
    end
    @maybethreaded threaded for rule ∈ other_rules 
        to = TimerOutput()
        @timeit to repr(rule) begin
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
                lock(mlock) do 
                    append!(matches, rule_matches) 
                end
            end
        end
        merge!(report.to, to, tree_point=timer_tree_point)
    end
    return matches
end
    