module EGraphs

include("../docstrings.jl")

using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)

# import ..Rule
# import ..getrhsfun

using ..TermInterface
using ..Util
using ..Rules
import ..@log


include("enode.jl")
export ENode

include("abstractanalysis.jl")
export AbstractAnalysis

include("eclass.jl")
export EClass
export hasdata
export getdata
export setdata!

include("intdisjointmap.jl")
export IntDisjointSet
export in_same_set

include("egg.jl")
export find
export geteclass
export arity
export EGraph
export merge!
export in_same_class
export addexpr!
export rebuild!
export prune!


include("analysis.jl")
export analyze!

# include("substitution.jl")
# export instantiate
# export instantiateterm

include("new_sub.jl")
export Sub


# include("ematch.jl")
include("new_ematch.jl")
include("Schedulers/Schedulers.jl")
export Schedulers
using .Schedulers

include("saturation_goal.jl")
export SaturationGoal
export EqualityGoal
export reached

include("saturation_reason.jl")
export ReportReasons

include("saturation_report.jl")
include("saturation_params.jl")
export SaturationParams

include("saturation_search.jl")
include("saturation_apply.jl")

include("saturation.jl")
export saturate!
include("equality.jl")
export areequal
export @areequal
export @areequalg

include("extraction.jl")
export extract!
export ExtractionAnalysis
export astsize
export astsize_inv
export @extract

end
