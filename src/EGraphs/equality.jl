function areequal(theory::Vector{Rule}, exprs...)
    G = EGraph(exprs[1])
    areequal(G, theory, exprs...)
end

function areequal(G::EGraph, t::Vector{Rule}, exprs...)
    @info "Checking equality for " exprs
    if length(exprs) == 1; return true end

    ids = []
    for i ∈ exprs
        ec = addexpr!(G, cleanast(i))
        push!(ids, ec.id)
    end

    alleq = () -> (all(x -> in_same_set(G.U, ids[1], x), ids[2:end]))

    @time saturate!(G, t; timeout=6, sizeout=2^12, stopwhen=alleq)

    alleq()
end

macro areequal(theory, exprs...)
    t = gettheory(theory, __module__; compile=false)
    areequal(t, exprs...)
end

macro areequalg(G, theory, exprs...)
    t = gettheory(theory, __module__; compile=false)
    areequal(getfield(__module__, G), t, exprs...)
end
