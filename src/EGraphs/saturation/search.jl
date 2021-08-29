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

"""
Returns an iterator of `Match`es.
"""
function eqsat_search!(egraph::EGraph, theory::Vector{<:AbstractRule},
    scheduler::AbstractScheduler, report; threaded=false)
    match_groups = Vector{Match}[]
    function pmap(f, xs) 
        # const propagation should be able to optimze one of the branch away
        if threaded
            # # try to divide the work evenly between threads without adding much overhead
            # chunks = Threads.nthreads() * 10
            # basesize = max(length(xs) ÷ chunks, 1)
            # ThreadsX.mapi(f, xs; basesize=basesize) 
            ThreadsX.map(f, xs)
        else
            map(f, xs)
        end
    end

    inequalities = filter(Base.Fix2(isa, UnequalRule), theory)
    # never skip contradiction checks
    append_time = TimerOutput()
    for rule ∈ inequalities
        @timeit report.to repr(rule) begin
            ids = cached_ids(egraph, rule.left)
            rule_matches = pmap(i -> rule(egraph, i), ids)
            @timeit append_time "appending matches" begin
                append!(match_groups, rule_matches)
            end
        end
    end

    other_rules = filter(theory) do rule 
        !(rule isa UnequalRule)
    end
    for rule ∈ other_rules 
        @timeit report.to repr(rule) begin
            # don't apply banned rules
            if !cansearch(scheduler, rule)
                # println("skipping banned rule $rule")
                continue
            end

            ids = cached_ids(egraph, rule.left)
            rule_matches = pmap(i -> rule(egraph, i), ids)

            n_matches = sum(length, rule_matches)
            can_yield = inform!(scheduler, rule, n_matches)
            if can_yield
                @timeit append_time "appending matches" begin
                    append!(match_groups, rule_matches)
                end
            end
        end
    end

    # @timeit append_time "appending matches" begin
    #     result = reduce(vcat, match_groups) # this should be more efficient than multiple appends
    # end
    merge!(report.to, append_time, tree_point=["Search"])

    return Iterators.flatten(match_groups)
    # return result
end
    