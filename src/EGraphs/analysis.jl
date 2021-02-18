function addanalysis!(G::EGraph, AnType::Type{<:AbstractAnalysis}, args...)
    for i ∈ G.analyses
        typeof(i) isa AnType && return nothing
    end
    analysis = AnType(G, args...)
    push!(G.analyses, analysis)

    did_something = true
    while did_something
        did_something = false

        for (id, class) ∈ G.M
            id = find(G, id)
            pass = make_pass(G, analysis, id)
            # pass = make_pass(G, analysis, find(G,id))

            if pass !== missing
                if pass !== get(analysis, id, missing)
                    analysis[id] = pass
                    did_something = true
                end
                modify!(analysis, id)
            end
        end
    end



    for (id, class) ∈ G.M
        id = find(G, id)
        if !haskey(analysis, id)
            display(G.M); println()
            display(analysis.data); println()
            error("failed to compute analysis for eclass ", id)
        end
    end

    rebuild!(G)

    return analysis
end

function make_pass(g::EGraph, analysis::AbstractAnalysis, id::Int64)
    class = g.M[id]
    for n ∈ class
        if n isa Expr
            start = Meta.isexpr(n, :call) ? 2 : 1
            if !all(x -> haskey(analysis, find(g, x.id)), n.args[start:end])
                return missing
            end
        end
    end

    joined = make(analysis, class[1])

    for n ∈ class
        datum = make(analysis, n)
        joined = join(analysis, joined, datum)
    end
    return joined
end

# TODO document AbstractAnalysis

modify!(analysis::AbstractAnalysis, id::Int64) =
    error("Analysis does not implement modify!")
join(analysis::AbstractAnalysis, a, b) =
    error("Analysis does not implement join")
make(analysis::AbstractAnalysis, a) =
    error("Analysis does not implement make")

Base.haskey(analysis::AbstractAnalysis, id::Int64) =
    error("Analysis does not implement haskey")
Base.haskey(analysis::AbstractAnalysis, ec::EClass) =
    haskey(analysis, ec.id)


Base.getindex(analysis::AbstractAnalysis, id::Int64) =
    error("Analysis does not implement getindex")
Base.getindex(analysis::AbstractAnalysis, ec::EClass) = analysis[ec.id]

Base.setindex!(analysis::AbstractAnalysis, value, id::Int64) =
    error("Analysis does not implement setindex!")
Base.setindex!(analysis::AbstractAnalysis, value, ec::EClass) =
    setindex!(analysis, ec.id, value)

Base.delete!(analysis::AbstractAnalysis, id::Int64) =
    error("Analysis does not implement delete!")
Base.delete!(analysis::AbstractAnalysis, ec::EClass) =
    setindex!(analysis, ec.id, value)

Base.get(an::AbstractAnalysis, id::Int64, default) = haskey(an, id) ? an[id] : default
Base.get(an::AbstractAnalysis, ec::EClass, default) = get(an, ec.id, default)
