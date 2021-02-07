function addanalysis!(G::EGraph, analysis::AbstractAnalysis)
    if haskey(G.analyses, analysis); return end
    data = G.analyses[analysis] = Dict{Int64, Any}()
    # for (k,v) ∈ G.M
    #     data[k] = nothing
    # end
end

modify!(analysis::AbstractAnalysis, G::EGraph, id::Int64) = error("Analysis does not implement modify!")
join(analysis::AbstractAnalysis, G::EGraph, a, b) = error("Analysis does not implement join")
make(analysis::AbstractAnalysis, G::EGraph, a) = error("Analysis does not implement make")
