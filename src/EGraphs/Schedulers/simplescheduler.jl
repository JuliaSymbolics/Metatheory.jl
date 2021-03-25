"""
A simple Rewrite Scheduler that applies every rule every time
"""
struct SimpleScheduler <: AbstractScheduler end

cansaturate(s::SimpleScheduler) = true
shouldskip(s::SimpleScheduler, r::Rule) = false

function SimpleScheduler(G::EGraph, theory::Vector{<:Rule})
    SimpleScheduler()
end

readstep!(s::SimpleScheduler) = nothing
writestep!(s::SimpleScheduler, r::Rule) = nothing
