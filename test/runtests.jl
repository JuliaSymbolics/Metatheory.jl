using Metatheory
using Metatheory.Classic
using Metatheory.EGraphs
using Metatheory.Library
using Metatheory.Util

using DataStructures
using Test

# Metatheory.options[:verbose] = true
# Metatheory.options[:printiter] = true

@metatheory_init

Test.FallbackTestSet(desc) = Test.FallbackTestSet()

ts = Test.FallbackTestSet

@testset ts "Metatheory Tests" begin
   @timev begin
      include("test_egraphs.jl")
      include("test_ematch.jl")
      include("test_ematch_assertions.jl")
      include("test_analysis.jl")
      include("test_extraction.jl")
      include("test_dynamic_ematch.jl")
      # FIXME include("test_mu.jl")
      include("test_boson.jl")
      include("test_while_interpreter.jl")
      include("test_theories.jl")
      include("test_reductions.jl")
      include("test_taylor.jl")
      include("test_while_superinterpreter.jl")
      include("test_fibonacci.jl")
      include("test_cat.jl")
      include("test_calculational_logic.jl")
      include("test_logic.jl")
      include("test_inequality.jl")
      include("test_cas.jl")
      include("test_custom_types.jl")


      # exported consistency test
      for m ∈ [Metatheory, Metatheory.Util, Metatheory.Classic, Metatheory.EGraphs, Metatheory.EGraphs.Schedulers]
         for i ∈ propertynames(m)
            xxx = getproperty(m, i)
         end
      end
   end
end
