function addanalysis!(g::EGraph, an::Type{<:AbstractAnalysis})
    push!(g.analyses, an)
    if !islazy(an)
        analyze!(g, an)
    end
end


analyze!(g::EGraph, an::Type{<:AbstractAnalysis}, id::Int64) =
    analyze!(g, an, reachable(g, id))


function analyze!(g::EGraph, an::Type{<:AbstractAnalysis})
    analyze!(g, an, collect(keys(g.emap)))
end

"""

**WARNING**. This function is unstable.
An [`EGraph`](@ref) can only contain one analysis of type `an`.
"""
function analyze!(g::EGraph, an::Type{<:AbstractAnalysis}, ids::Vector{Int64})
    push!(g.analyses, an)
    ids = sort(ids)
    # @assert isempty(g.dirty)

    did_something = true
    while did_something
        did_something = false

        for id ∈ ids
            eclass = geteclass(g, id)
            id = eclass.id
            pass = mapreduce(x -> make(an, g, x), (x, y) -> join(an, x, y), eclass)
            # pass = make_pass(G, analysis, find(G,id))

            # if pass !== missing
            if pass !== getdata(eclass, an, missing)
                setdata!(eclass, an, pass)
                did_something = true
                push!(g.dirty, id)
            end
        end
    end

    for id ∈ ids
        eclass = geteclass(g, id)
        id = eclass.id
        if !hasdata(eclass, an)
            # display(g.emap[id]); println()
            # display(analysis.data); println()
            error("failed to compute analysis for eclass ", id)
        end
    end

    rebuild!(g)

    # display(analysis.data); println()

    return true
end
