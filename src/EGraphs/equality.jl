function areequal(theory::Vector{<:Rule}, exprs...;
    mod=@__MODULE__, params=SaturationParams())
    G = EGraph(exprs[1])
    areequal(G, theory, exprs...; params=params)
end

function areequal(G::EGraph, t::Vector{<:Rule}, exprs...;
    mod=@__MODULE__, params=SaturationParams())
    @log "Checking equality for " exprs
    if length(exprs) == 1; return true end

    ids = []
    for i ∈ exprs
        ec = addexpr!(G, i)
        push!(ids, ec.id)
    end

    # rebuild!(G)

    @log "starting saturation"

    alleq = () -> (all(x -> in_same_set(G.uf, ids[1], x), ids[2:end]))

    params.stopwhen = alleq

    report = saturate!(G, t, params; mod=mod)

    # display(G.classes); println()

    alleq()
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
