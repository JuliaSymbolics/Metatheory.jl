function areequal(theory::Vector{Rule}, exprs...;
    timeout=0, sizeout=2^12, mod=@__MODULE__)
    G = EGraph(exprs[1])
    areequal(G, theory, exprs...;
        timeout=timeout, sizeout=sizeout, mod=mod)
end

function areequal(G::EGraph, t::Vector{Rule}, exprs...;
    timeout=0, sizeout=2^12, mod=@__MODULE__)
    @debug "Checking equality for " exprs
    if length(exprs) == 1; return true end

    ids = []
    for i ∈ exprs
        ec = addexpr!(G, i)
        push!(ids, ec.id)
    end

    # rebuild!(G)

    @info "starting saturation"

    alleq = () -> (all(x -> in_same_set(G.U, ids[1], x), ids[2:end]))

    @time saturate!(G, t; timeout=timeout,
        sizeout=sizeout, stopwhen=alleq, mod=mod)

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
