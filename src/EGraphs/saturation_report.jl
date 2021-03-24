
const TimeData = NamedTuple{(:time, :bytes, :gctime),
    Tuple{Float64, Int64, Float64}}

# string representation of timedata
function Base.show(io::IO, x::TimeData)
    print(io, "(")
    ks = keys(x)
    for i ∈ 1:length(ks)
        k = ks[i]
        print(io, "$k = $(getfield(x, k))")
        i < length(ks) ? print(io, ", ") : print(io, ")")
    end
end

"""
Construct a [`TimeData`](@ref) from a `NamedTuple` returned by `@timed`
"""
discard_value(stats::NamedTuple) = (
    time=stats.time,
    bytes=stats.bytes,
    gctime=stats.gctime,
)

const EmptyTimeData = (time=0.0, bytes=0, gctime=0.0)

# =============================================================================


mutable struct Report
    # TODO move this to a custom type
    reason::Union{ReportReasons.ReportReason, Nothing}
    egraph::EGraph
    iterations::Int
    search_stats::TimeData
    apply_stats::TimeData
    rebuild_stats::TimeData
    total_time::TimeData
end

Report() = Report(nothing, EGraph(), 0,
    EmptyTimeData, EmptyTimeData, EmptyTimeData, EmptyTimeData)

Report(g::EGraph) = Report(nothing, g, 0,
    EmptyTimeData, EmptyTimeData, EmptyTimeData, EmptyTimeData)


function total_time!(r::Report)
    r.total_time = r.search_stats + r.apply_stats + r.rebuild_stats
end

# string representation of timedata
function Base.show(io::IO, x::Report)
    g = x.egraph
    println(io, "Equality Saturation Report")
    println(io, "=================")
    println(io, "\tStop Reason: $(x.reason)")
    println(io, "\tIterations: $(x.iterations)")
    println(io, "\tEGraph Size: $(length(g.emap)) eclasses, $(length(g.hashcons)) nodes")
    println(io, "\tTotal Time: $(x.total_time)")
    println(io, "\tSearch Time: $(x.search_stats)")
    println(io, "\tApply Time: $(x.apply_stats)")
    println(io, "\tRebuild Time: $(x.rebuild_stats)")
end


import Base.(+)
function (+)(a::TimeData, b::TimeData)
    (time=a.time+b.time, bytes=a.bytes+b.bytes, gctime=a.gctime+b.gctime)
end

function (+)(a::Report, b::Report)
    Report(b.reason, b.egraph, a.iterations+b.iterations,
        a.search_stats + b.search_stats,
        a.apply_stats + b.apply_stats,
        a.rebuild_stats + b.rebuild_stats,
        a.total_time + b.total_time
    )
end
