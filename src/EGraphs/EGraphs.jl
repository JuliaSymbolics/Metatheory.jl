# module EGraphs

include("enode.jl")
include("egg.jl")
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
export countexprs
export areequal
export @areequal
export @areequalg


# end
