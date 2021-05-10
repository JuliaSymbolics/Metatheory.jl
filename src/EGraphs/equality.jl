function areequal(theory::Vector{<:Rule}, exprs...;
    mod=@__MODULE__, params=SaturationParams())
    g = EGraph(exprs[1])
    areequal(g, theory, exprs...; params=params)
end

function areequal(g::EGraph, t::Vector{<:Rule}, exprs...;
    mod=@__MODULE__, params=SaturationParams())
    @log "Checking equality for " exprs
    if length(exprs) == 1; return true end
    # rebuild!(G)

    @log "starting saturation"

    n = length(exprs)
    ids = Vector{EClassId}(undef, n)
    nodes = Vector{ENode}(undef, n)
    for i ∈ 1:n
        ec, node = addexpr!(g, exprs[i])
        ids[i] = ec.id
        nodes[i] = node
    end

    goal = EqualityGoal(collect(exprs), ids)
    
    # alleq = () -> (all(x -> in_same_set(G.uf, ids[1], x), ids[2:end]))

    params.goal = goal
    # params.stopwhen = alleq

    report = saturate!(g, t, params; mod=mod)

    # display(g.classes); println()
    if !(report.reason isa Saturated) && !reached(g, goal)
        return missing # failed to prove
    end
    return reached(g, goal)
end

import ..gettheory

macro areequal(theory, exprs...)
    t = gettheory(theory, __module__; compile=false)
    areequal(t, exprs...; mod=__module__)
end

macro areequalg(G, theory, exprs...)
    t = gettheory(theory, __module__; compile=false)
    areequal(getfield(__module__, G), t, exprs...; mod=__module__)
end
