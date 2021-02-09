MatchesBuf = Vector{Tuple{Rule, Sub, Int64}}


function eqsat_step!(G::EGraph, theory::Vector{Rule}; scheduler=SimpleScheduler())

    matches=MatchesBuf()

    EMPTY_DICT = Base.ImmutableDict{Any, EClass}()

    readstep(scheduler)

    for rule ∈ theory
        # don't apply banned rules
        shouldskip(scheduler, rule) && continue


        rule.mode != :rewrite && error("unsupported rule mode")
        for id ∈ keys(G.M)
            # println(rule.right)
            for sub in ematch(G, rule.left, id, EMPTY_DICT)
                # display(sub); println()
                !isempty(sub) && push!(matches, (rule, sub, id))
            end
            # for sub in ematch(G, rule.right, id, EMPTY_DICT)
            #     # display(sub); println()
            #     !isempty(sub) && push!(matches, (rule, sub, id))
            # end
        end
    end

    # @info "write phase"
    for (rule, sub, id) ∈ matches
        writestep(scheduler, rule)

        l = instantiate(G,rule.left,sub; skip_assert=true)
        r = instantiate(G,rule.right,sub)
        merge!(G,l.id,r.id)
    end

    # display(G.parents); println()
    # display(G.M); println()
    saturated = isempty(G.dirty)
    rebuild!(G)
    return saturated, G
end

# TODO plot how egraph shrinks and grows during saturation
function saturate!(G::EGraph, theory::Vector{Rule};
    timeout=6, stopwhen=(()->false), sizeout=2^12,
    scheduler::Type{<:AbstractScheduler}=BackoffScheduler)

    curr_iter = 0

    theory = map(theory) do rule
        r = deepcopy(rule)
        r.left = df_walk(eval_types_in_assertions, r.left; skip_call=true)
        r
    end

    # init scheduler
    sched = scheduler(G, theory)

    while true
        # @info curr_iter
        curr_iter+=1
        saturated, G = eqsat_step!(G, theory; scheduler=sched)

        cansaturate(sched) && saturated && (@info "E-GRAPH SATURATED"; break)
        curr_iter >= timeout && (@info "E-GRAPH TIMEOUT"; break)
        sizeout > 0 && length(G.U) > sizeout && (@info "E-GRAPH SIZEOUT"; break)
        stopwhen() && (@info "Halting requirement satisfied"; break)
    end
    return G
end



# TODO is there anything better than eval to use here?
"""
When creating a theory, type assertions in the left hand contain symbols.
We want to replace the type symbols with the real type values, to fully support
the subtyping mechanism during pattern matching.
"""
function eval_types_in_assertions(x)
    if isexpr(x, :(::))
        !(x.args[1] isa Symbol) && error("Type assertion is not on metavariable")
        Expr(:(::), x.args[1], eval(x.args[2]))
    else x
    end
end
