abstract type SaturationGoal end

reached(g::EGraph, goal::Nothing) = false
reached(g::EGraph, goal::SaturationGoal) = false

"""
This goal is reached when the `exprs` list of expressions are in the 
same equivalence class.
"""
struct EqualityGoal <: SaturationGoal
    exprs::Vector{Any}
    ids::Vector{Int64}
    function EqualityGoal(exprs, eclasses) 
        @assert length(exprs) == length(eclasses) && length(exprs) != 0 
        new(exprs, eclasses)
    end
end

function EqualityGoal(g::EGraph, exprs)
    n = length(exprs)
    ids = Vector{Int64}(undef, n)
    for i ∈ 1:n
        ec = addexpr!(g, exprs[i])
        ids[i] = ec.id
    end
    return EqualityGoal(exprs, ids)
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

