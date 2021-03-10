module EGraphs

include("../docstrings.jl")

using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)

import ..Rule
import ..iscall
import ..istree
import ..getfunsym
import ..getfunargs
import ..setfunsym!
import ..setfunargs!


using ..Util

include("eclass.jl")
include("enode.jl")
export isenode

include("egg.jl")
export find
export EClass
export EGraph
export AbstractAnalysis
export merge!
export addexpr!
export addanalysis!
export rebuild!

include("analysis.jl")


include("ematch.jl")
include("Schedulers/Schedulers.jl")

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
