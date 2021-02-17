module EGraphs

using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)

import ..Rule
using ..Util

include("enode.jl")
export isenode

include("egg.jl")
include("analysis.jl")


include("ematch.jl")
include("Schedulers/Schedulers.jl")
include("theory_compiler.jl")
include("saturation.jl")
include("equality.jl")

include("extraction.jl")

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

export extract!
export ExtractionAnalysis

export astsize

end
