abstract type AbstractAnalysis end

# TODO document AbstractAnalysis

# modify!(analysis::Type{<:AbstractAnalysis}, eclass::EClass) =
#     error("Analysis does not implement modify!")
islazy(an::Type{<:AbstractAnalysis})::Bool = false
modify!(analysis::Type{<:AbstractAnalysis}, g, id) = nothing
join(analysis::Type{<:AbstractAnalysis}, a, b) =
    error("Analysis does not implement join")
make(analysis::Type{<:AbstractAnalysis}, g, a) =
    error("Analysis does not implement make")

