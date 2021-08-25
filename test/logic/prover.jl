using Metatheory
using Metatheory.EGraphs
using TermInterface

function prove(t, ex, steps=1, timeout=10, eclasslimit=5000)
    params = SaturationParams(timeout=timeout, eclasslimit=eclasslimit, 
    # scheduler=Schedulers.ScoredScheduler, schedulerparams=(1000,5, Schedulers.exprsize))
    scheduler=Schedulers.BackoffScheduler, schedulerparams=(6000,5))

    hist = UInt64[]
    push!(hist, hash(ex))
    for i ∈ 1:steps
        g = EGraph(ex)

        exprs = [true, geteclass(g, g.root)]
        ids = [addexpr!(g, e)[1].id for e in exprs]

        goal=EqualityGoal(exprs, ids)
        params.goal = goal
        saturate!(g, t, params)
        ex = extract!(g, astsize)
        println(ex)
        if !TermInterface.istree(typeof(ex))
            return ex
        end
        if hash(ex) ∈ hist
            println("loop detected")
            return ex
        end
        push!(hist, hash(ex))
    end
    return ex
end

