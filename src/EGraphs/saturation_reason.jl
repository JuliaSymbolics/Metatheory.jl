module ReportReasons

"""
Abstract type to represent the reason why equality saturation halted 
"""
abstract type ReportReason end

struct Saturated <: ReportReason end
Base.show(io::IO, x::Saturated) = print(io, "EGraph Saturated")
export Saturated

struct Timeout <: ReportReason end
Base.show(io::IO, x::Timeout) = print(io, "Iteration Timeout")
export Timeout

struct ConditionSatisfied <: ReportReason end
Base.show(io::IO, x::ConditionSatisfied) = print(io, "Halting condition satisfied")
export ConditionSatisfied

struct Contradiction <: ReportReason end
Base.show(io::IO, x::Contradiction) = print(io, "Equality Contradiction detected")
export Contradiction

struct EClassLimit <: ReportReason 
    limit::Int
end
Base.show(io::IO, x::EClassLimit) = print(io, "Limit of $(x.limit) EClasses Exceeded")
export EClassLimit

struct NodeLimit <: ReportReason end
Base.show(io::IO, x::NodeLimit) = print(io, "ENode Limit Exceeded")
export NodeLimit

end