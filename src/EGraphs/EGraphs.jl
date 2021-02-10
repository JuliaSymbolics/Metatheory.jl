# module EGraphs

include("enode.jl")
include("egg.jl")
include("analysis.jl")
include("ematch.jl")
include("schedulers/abstractscheduler.jl")
include("schedulers/simplescheduler.jl")
include("schedulers/backoffscheduler.jl")
include("saturation.jl")
include("equality.jl")



export EClass
export EGraph
export AbstractAnalysis
export merge!
export addexpr!
export addanalysis!
export rebuild!
export saturate!
export areequal
export @areequal
export @areequalg

include("extraction.jl")
export extract!
export ExtractionAnalysis
export make
export join
export modify!
export astsize


# end
