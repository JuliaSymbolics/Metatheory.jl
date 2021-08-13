module EGraphs

include("../docstrings.jl")

using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)

using TermInterface
using ..Util
using ..Patterns
using ..Rules
import ..@log
import ..iscall

include("enode.jl")
export ENode
export EClassId

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

include("metadata_analysis.jl")
export MetadataAnalysis

include("egraph.jl")
export find
export lookup
export geteclass
export arity
export EGraph
export merge!
export in_same_class
export addexpr!
export rebuild!
export settermtype!
export gettermtype

include("analysis.jl")
export analyze!

include("subst.jl")
export Sub

include("ematch.jl")
include("Schedulers/Schedulers.jl")
export Schedulers
using .Schedulers

include("saturation/goal.jl")
export SaturationGoal
export EqualityGoal
export reached
include("saturation/reason.jl")
export ReportReasons
include("saturation/report.jl")
include("saturation/params.jl")
export SaturationParams
include("saturation/search.jl")
include("saturation/apply.jl")
include("saturation/saturation.jl")
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
