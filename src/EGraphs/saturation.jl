const MatchesBuf = Vector{Tuple{Rule, Sub, Int64}}

using .Schedulers


inst(var, egraph::EGraph, sub::Sub) =
    haskey(sub, var) ? first(sub[var]) : add!(egraph, var)
inst(p::Expr, egraph::EGraph, sub::Sub) = add!(egraph, p)

function instantiate(egraph::EGraph, p, sub::Sub; skip_assert=false)
    # remove type assertions
    if skip_assert
        p = df_walk( x -> (isexpr(x, :ematch_tassert) ? x.args[1] : x), p; skip_call=true )
    end

    df_walk(inst, p, egraph, sub; skip_call=true)
end

function get_actual_param(var, sub::Sub)
     if haskey(sub, var)
         (eclass, literal) = sub[var]
         literal != nothing ? literal : eclass
     else
         error("internal error in dynamic rule application")
     end
end


function eqsat_step!(egraph::EGraph, theory::Vector{Rule};
        scheduler=SimpleScheduler(), rhs_funs=RhsFunCache())
    matches=MatchesBuf()
    EMPTY_DICT = Sub()

    readstep!(scheduler)

    for rule ∈ theory
        # don't apply banned rules
        shouldskip(scheduler, rule) && continue

        if rule.mode == :rewrite || rule.mode == :dynamic
            for id ∈ keys(egraph.M)
                # println(rule.right)
                for sub in ematch(egraph, rule.left, id, EMPTY_DICT)
                    # display(sub); println()
                    !isempty(sub) && push!(matches, (rule, sub, id))
                end
                # for sub in ematch(egraph, rule.right, id, EMPTY_DICT)
                #     # display(sub); println()
                #     !isempty(sub) && push!(matches, (rule, sub, id))
                # end
            end
        else
            error("unsupported rule mode")
        end
    end

    # @info "write phase"
    for (rule, sub, id) ∈ matches
        writestep!(scheduler, rule)

        if rule.mode == :rewrite # symbolic replacement
            l = instantiate(egraph,rule.left,sub; skip_assert=true)
            r = instantiate(egraph,rule.right,sub)
            merge!(egraph,l.id,r.id)
        elseif rule.mode == :dynamic # execute the right hand!
            l = instantiate(egraph,rule.left,sub; skip_assert=true)

            (params, f) = rhs_funs[rule]
            actual_params = params .|> x -> get_actual_param(x, sub)
            r = addexpr!(egraph, f(egraph, actual_params...))
            merge!(egraph,l.id,r.id)
        else
            error("unsupported rule mode")
        end
    end

    # display(egraph.parents); println()
    # display(egraph.M); println()
    saturated = isempty(egraph.dirty)
    rebuild!(egraph)
    return saturated, egraph
end

# TODO plot how egraph shrinks and grows during saturation
function saturate!(egraph::EGraph, theory::Vector{Rule};
    mod=@__MODULE__,
    timeout=7, stopwhen=(()->false), sizeout=2^12,
    scheduler::Type{<:AbstractScheduler}=BackoffScheduler)

    println(mod)
    curr_iter = 0

    # evaluate types in type assertions and generate the
    # dynamic rule right hand side function cache
    rhs_funs = RhsFunCache()
    theory = map(theory) do rule
        r = deepcopy(rule)
        r.left = df_walk(x -> eval_types_in_assertions(x, mod), r.left; skip_call=true)
        if r.mode == :dynamic && !haskey(rhs_funs, r)
            rhs_funs[r] = genrhsfun(r, mod)
        end
        r
    end

    # init the scheduler
    sched = scheduler(egraph, theory)
    saturated = false

    while true
        # @info curr_iter
        curr_iter+=1
        saturated, egraph = eqsat_step!(egraph, theory; scheduler=sched, rhs_funs=rhs_funs)

        cansaturate(sched) && saturated && (@info "E-GRAPH SATURATED"; break)
        curr_iter >= timeout && (@info "E-GRAPH TIMEOUT"; break)
        sizeout > 0 && length(egraph.U) > sizeout && (@info "E-GRAPH SIZEOUT"; break)
        stopwhen() && (@info "Halting requirement satisfied"; break)
    end
    return saturated, egraph
end
