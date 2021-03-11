"""
Adds an [`AbstractAnalysis`](@ref) to an [`EGraph`](@ref).
An [`EGraph`](@ref) can only contain one analysis of type
`AnType`.
"""
function addanalysis!(g::EGraph, AnType::Type{<:AbstractAnalysis}, args...; lazy=false)
    for i ∈ g.analyses
        typeof(i) isa AnType && return nothing
    end
    analysis = AnType(g, args...)
    push!(g.analyses, analysis)

    !islazy(analysis) && analyze!(g, analysis, collect(keys(g.M)))

    return analysis
end

# FIXME doesnt work on cycles.
"""
**WARNING**. This function is unstable.
"""
function analyze!(g::EGraph, analysis::AbstractAnalysis, ids::Vector{Int64})
    ids = sort(ids)

    println(ids)

    @assert isempty(g.dirty)

    did_something = true
    while did_something
        did_something = false

        for id ∈ ids
            id = find(g, id)
            pass = mapreduce(x -> make(analysis, x),
                (x, y) -> join(analysis, x, y), g.M[id])
            # pass = make_pass(G, analysis, find(G,id))

            # if pass !== missing
            if pass !== get(analysis, id, missing)
                analysis[id] = pass
                # println("analysis value for $id is $(analysis[id])")
                did_something = true
                # modify!(analysis, id)
                push!(g.dirty, id)
            end
            # end
        end
    end

    for id ∈ ids
        id = find(g, id)
        if !haskey(analysis, id)
            display(g.M[id]); println()
            # display(analysis.data); println()
            error("failed to compute analysis for eclass ", id)
        end
    end

    rebuild!(g)

    # display(analysis.data); println()

    return analysis
end

analyze!(g::EGraph, an::AbstractAnalysis, id::Int64) =
    analyze!(g, an, reachable(g, id))

function make_pass(g::EGraph, analysis::AbstractAnalysis, id::Int64)
    class = g.M[id]
    # FIXME this check breaks things. wtf
    # for n ∈ class
        # if !all(x -> haskey(analysis, find(g, x.id)), n.args[start:end])
        # any(x -> find(g, x.id) == find(g, id), n.args[start:end]) &&
        #     continue\
        # @assert all(x -> haskey(analysis, x), n.args)
        # if !all(x -> haskey(analysis, x), n.args)
        #     return missing
        # end

    # end

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

islazy(an::AbstractAnalysis)::Bool = false
