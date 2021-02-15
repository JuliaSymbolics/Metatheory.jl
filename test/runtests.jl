using Metatheory
using Metatheory.Library

using DataStructures
using Test

include("../src/util.jl")

Metatheory.init(@__MODULE__)

include("test_theories.jl")
include("test_reductions.jl")
include("test_egraphs.jl")
include("test_ematch.jl")
include("test_ematch_assertions.jl")
include("test_analysis.jl")
include("test_dynamic_ematch.jl")
include("test_extraction.jl")
include("test_mu.jl")
include("test_while_interpreter.jl")
# include("test_while_superinterpreter.jl")

# exported consistency test
for i ∈ propertynames(Metatheory)
   x = getproperty(Metatheory, i)
end
