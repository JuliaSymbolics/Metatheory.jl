using TimerOutputs



mutable struct Report
    reason::Union{ReportReasons.ReportReason, Nothing}
    egraph::EGraph
    iterations::Int
    to::TimerOutput
end

Report() = Report(nothing, EGraph(), 0, TimerOutput())

Report(g::EGraph) = Report(nothing, g, 0, TimerOutput())



# string representation of timedata
function Base.show(io::IO, x::Report)
    g = x.egraph
    println(io, "Equality Saturation Report")
    println(io, "=================")
    println(io, "\tStop Reason: $(x.reason)")
    println(io, "\tIterations: $(x.iterations)")
    # println(io, "\tRules applied: $(g.age)")
    println(io, "\tEGraph Size: $(g.numclasses) eclasses, $(length(g.memo)) nodes")
    print_timer(io, x.to)
end
