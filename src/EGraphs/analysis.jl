function addanalysis!(G::EGraph, analysis::AbstractAnalysis)
    if haskey(G.analyses, analysis); return end
    data = G.analyses[analysis] = Dict{Int64, Any}()

    did_something = true
    while did_something
        did_something = false

        for (id, class) ∈ G.M
            pass = make_pass(G, id, data, analysis)

            if !haskey(data, id) || (haskey(data, id) && pass != data[id]) && pass != nothing # && ???
                data[id] = pass
                did_something = true
            end
            # push!(G.dirty, id)
            modify!(analysis, G, id)
        end
    end

    for (id, class) ∈ G.M
        if !haskey(data,id)
            error("failed to compute analysis for eclass ", id)
        end
    end
end

function make_pass(G::EGraph, id::Int64, data, analysis::AbstractAnalysis)
    class = G.M[id]
    for n ∈ class
        if n isa Expr
            start = Meta.isexpr(n, :call) ? 2 : 1
            if !all(x -> haskey(data, x.id), n.args[start:end])
                return nothing
            end
        end
    end


    joined = make(analysis, G, class[1])

    for n ∈ class
        datum = make(analysis, G, n)
        joined = join(analysis, G, joined, datum)
    end
    return joined
end

modify!(analysis::AbstractAnalysis, G::EGraph, id::Int64) =
    error("Analysis does not implement modify!")
join(analysis::AbstractAnalysis, G::EGraph, a, b) =
    error("Analysis does not implement join")
make(analysis::AbstractAnalysis, G::EGraph, a) =
    error("Analysis does not implement make")
