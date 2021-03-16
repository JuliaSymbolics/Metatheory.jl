module EGraphs

include("../docstrings.jl")

using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)

import ..Rule
using ..TermInterface

using ..Util

include("enode.jl")
include("eclass.jl")

include("egg.jl")
export find
export EClass
export ENode
export ariety
export EGraph
export AbstractAnalysis
export merge!
export addexpr!
export addanalysis!
export rebuild!

include("analysis.jl")


include("ematch.jl")
include("Schedulers/Schedulers.jl")
export Schedulers


include("saturation_report.jl")
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
