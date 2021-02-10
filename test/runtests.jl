using Metatheory
using DataStructures
using Test

include("../src/util.jl")

include("test_theories.jl")
include("test_reductions.jl")
include("test_egraphs.jl")
include("test_ematch.jl")
include("test_ematch_assertions.jl")
include("test_analysis.jl")
include("test_extraction.jl")
include("test_while_interpreter.jl")

# exported consistency test
for i ∈ propertynames(Metatheory)
   x = getproperty(Metatheory, i)
end
