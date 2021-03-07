const MatchesBuf = Vector{Tuple{Rule, Sub, Int64}}

import ..genrhsfun
import ..options
import ..@log

using .Schedulers

inst(var, egraph::EGraph, sub::Sub) =
    haskey(sub, var) ? first(sub[var]) : add!(egraph, var)
inst(p::Expr, egraph::EGraph, sub::Sub) = add!(egraph, p)

function instantiate(egraph::EGraph, p, sub::Sub; skip_assert=false)
    # remove type assertions
    if skip_assert
        p = df_walk( x -> (isexpr(x, :(::)) ? x.args[1] : x), p; skip_call=true )
    end

    df_walk(inst, p, egraph, sub; skip_call=true)
end

function eqsat_step!(egraph::EGraph, theory::Vector{Rule};
        scheduler=SimpleScheduler(), mod=@__MODULE__)
    matches=MatchesBuf()
    EMPTY_DICT = Sub()

    readstep!(scheduler)

    for rule ∈ theory
        # don't apply banned rules
        shouldskip(scheduler, rule) && continue

        if rule.mode ∉ [:rewrite, :dynamic, :equational]
            error("unsupported mode in rule ", rule)
        end

        # TODO this entire loop is not needed. Only access
        # the eclasses where the outermost funcall appears!

        # outermost symbol in lhs
        sym = getfunsym(rule.left)
        ids = get(egraph.symcache, sym, [])

        for id ∈ ids
            for sub in ematch(egraph, rule.left, id, EMPTY_DICT)
                # display(sub); println()
                !isempty(sub) && push!(matches, (rule, sub, id))
            end
        end

        if rule.mode == :equational
            sym = getfunsym(rule.right)
            ids = get(egraph.symcache, sym, [])
            for id ∈ ids
                for sub in ematch(egraph, rule.right, id, EMPTY_DICT)
                    # display(sub); println()
                    !isempty(sub) && push!(matches, (rule, sub, id))
                end
            end
        end


    end

    for (rule, sub, id) ∈ matches
        writestep!(scheduler, rule)

        if rule.mode == :rewrite || rule.mode == :equational # symbolic replacement
            l = instantiate(egraph,rule.left,sub; skip_assert=true)
            r = instantiate(egraph,rule.right,sub)
            merge!(egraph,l.id,r.id)
        elseif rule.mode == :dynamic # execute the right hand!
            l = instantiate(egraph,rule.left,sub; skip_assert=true)
            (params, f) = rule.right_fun[mod]
            actual_params = map(params) do x
                (eclass, literal) = sub[x]
                literal != nothing ? literal : eclass
            end
            new = f(egraph, actual_params...)
            r = addexpr!(egraph, new)
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
"""
Given an [`EGraph`](@ref) and a collection of rewrite rules,
execute the equality saturation algorithm.
"""
function saturate!(egraph::EGraph, theory::Vector{Rule};
    mod=@__MODULE__,
    timeout=0, stopwhen=(()->false), sizeout=2^12,
    scheduler::Type{<:AbstractScheduler}=BackoffScheduler)

    if timeout == 0
        timeout = length(theory)
    end

    curr_iter = 0

    # prepare the dynamic rules in this module
    for rule ∈ theory
        if rule.mode == :dynamic && !haskey(rule.right_fun, mod)
            rule.right_fun[mod] = genrhsfun(rule.left, rule.right, mod)
        end
    end

    # init the scheduler
    sched = scheduler(egraph, theory)
    saturated = false

    while true
        curr_iter+=1
        # FIXME log
        # @log "iteration " curr_iter
        options[:printiter] && @info("iteration ", curr_iter)

        saturated, egraph = eqsat_step!(egraph, theory; scheduler=sched, mod=mod)

        cansaturate(sched) && saturated && (@log "E-GRAPH SATURATED"; break)
        curr_iter >= timeout && (@log "E-GRAPH TIMEOUT"; break)
        sizeout > 0 && length(egraph.U) > sizeout && (@log "E-GRAPH SIZEOUT"; break)
        stopwhen() && (@log "Halting requirement satisfied"; break)
    end
    return saturated, egraph
end
