"""
Adds an [`AbstractAnalysis`](@ref) to an [`EGraph`](@ref).
An [`EGraph`](@ref) can only contain one analysis of type
`AnType`.
The Analysis is computed for the whole EGraph. This
may be very slow for large EGraphs
"""
function addanalysis!(G::EGraph, AnType::Type{<:AbstractAnalysis}, args...; lazy=false)
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
                    # modify!(analysis, id)
                    push!(G.dirty, id)
                end
            end
        end
    end

    rebuild!(G)

    for (id, class) ∈ G.M
        # id = find(G, id)
        if !haskey(analysis, id)
            display(G.M); println()
            display(analysis.data); println()
            error("failed to compute analysis for eclass ", id)
        end
    end

    return analysis
end

function addlazyanalysis!(G::EGraph, AnType::Type{<:AbstractAnalysis}, args...; lazy=false)
    @warn "LAZY ANALYSES ARE AN UNSTABLE FEATURE!"
    for i ∈ G.lazy_analyses
        if typeof(i) isa AnType
            return nothing
        end
    end
    analysis = AnType(G, args...)
    push!(G.lazy_analyses, analysis)
    return analysis
end

# FIXME doesnt work on cycles.
"""
**WARNING**. This function is unstable.
"""
function lazy_analyze!(g::EGraph, analysis::AbstractAnalysis, id::Int64; hist=Int64[])
    id = find(g, id)
    hist = hist ∪ [id]
    did_something = true

    for n ∈ g.M[id]
        if n isa Expr
            start = Meta.isexpr(n, :call) ? 2 : 1
            for child_eclass ∈ n.args[start:end]
                c_id = child_eclass.id
                if !(c_id ∈ hist) && !haskey(analysis, c_id)
                    lazy_analyze!(g, analysis, c_id; hist)
                end
            end
        end
    end

    while did_something;
        did_something = false
        pass = make_pass(g, analysis, id)

        if pass !== missing;
            if pass !== get(analysis, id, missing)
                analysis[id] = pass
                did_something = true
                push!(g.dirty, id)
            end
        end
    end

    rebuild!(g)
    return get(analysis, id, missing)
end

function make_pass(g::EGraph, analysis::AbstractAnalysis, id::Int64; flexible=false)
    class = g.M[id]
    for n ∈ class
        if n isa Expr
            start = Meta.isexpr(n, :call) ? 2 : 1
            # if !all(x -> haskey(analysis, find(g, x.id)), n.args[start:end])
            flexible && any(x -> find(g, x.id) == find(g, id), n.args[start:end]) &&
                continue
            if !all(x -> haskey(analysis, x.id), n.args[start:end])
                return missing
            end
        end
    end

    joined = make(analysis, class[1])

    for n ∈ class
        datum = make(analysis, n)
        # println(datum)
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
