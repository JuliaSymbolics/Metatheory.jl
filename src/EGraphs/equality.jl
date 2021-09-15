function areequal(theory::Vector, exprs...; params=SaturationParams())
    g = EGraph(exprs[1])
    areequal(g, theory, exprs...; params=params)
end

function areequal(g::EGraph, t::Vector{<:AbstractRule}, exprs...; params=SaturationParams())
    @log "Checking equality for " exprs
    if length(exprs) == 1; return true end
    # rebuild!(G)

    @log "starting saturation"

    n = length(exprs)
    ids = Vector{EClassId}(undef, n)
    nodes = Vector{AbstractENode}(undef, n)
    for i ∈ 1:n
        ec, node = addexpr!(g, exprs[i])
        ids[i] = ec.id
        nodes[i] = node
    end

    goal = EqualityGoal(collect(exprs), ids)
    
    # alleq = () -> (all(x -> in_same_set(G.uf, ids[1], x), ids[2:end]))

    params.goal = goal
    # params.stopwhen = alleq

    report = saturate!(g, t, params)

    # display(g.classes); println()
    if !(report.reason isa Saturated) && !reached(g, goal)
        return missing # failed to prove
    end
    return reached(g, goal)
end

macro areequal(theory, exprs...)
    esc(:(areequal($theory, $exprs...))) 
end

macro areequalg(G, theory, exprs...)
    esc(:(areequal($G, $theory, $exprs...)))
end
