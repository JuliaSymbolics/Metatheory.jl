"""
A simple Rewrite Scheduler that applies every rule every time
"""
struct SimpleScheduler <: AbstractScheduler end

cansaturate(s::SimpleScheduler) = true
cansearch(s::SimpleScheduler, r::Rule) = true

function SimpleScheduler(G::EGraph, theory::Vector{<:Rule})
    SimpleScheduler()
end

inform!(s::SimpleScheduler, r, matches) = true

setiter!(s::SimpleScheduler, iteration) = nothing