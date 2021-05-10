abstract type SaturationGoal end

reached(g::EGraph, goal::Nothing) = false
reached(g::EGraph, goal::SaturationGoal) = false

"""
This goal is reached when the `exprs` list of expressions are in the 
same equivalence class.
"""
struct EqualityGoal <: SaturationGoal
    exprs::Vector{Any}
    ids::Vector{EClassId}
    function EqualityGoal(exprs, eclasses) 
        @assert length(exprs) == length(eclasses) && length(exprs) != 0 
        new(exprs, eclasses)
    end
end

function reached(g::EGraph, goal::EqualityGoal)
    all(x -> in_same_class(g, goal.ids[1], x), @view goal.ids[2:end])
end

"""
Boolean valued function as an arbitrary saturation goal.
User supplied function must take an [`EGraph`](@ref) as the only parameter.
"""
struct FunctionGoal <: SaturationGoal
    fun::Function
end

function reached(g::EGraph, goal::FunctionGoal)::Bool
    fun(g)    
end

