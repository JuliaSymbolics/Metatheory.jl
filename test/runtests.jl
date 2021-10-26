using SafeTestsets
using Metatheory
using Test

@timev begin
    @testset "All Tests" begin 
        @safetestset "Classical Rewriting" begin include("test_reductions.jl") end
        @safetestset "EGraphs Basics" begin include("test_egraphs.jl") end
        @safetestset "EMatch" begin include("test_ematch.jl") end
        @safetestset "EGraph Analysis" begin include("test_analysis.jl") end
        @safetestset "EGraph Extraction" begin include("test_extraction.jl") end
        @safetestset "Mu Puzzle" begin include("test_mu.jl") end
        @safetestset "While Interpreter" begin include("test_while_interpreter.jl") end
        @safetestset "Taylor Series" begin include("test_taylor.jl") end
        @safetestset "While Superinterpreter" begin include("test_while_superinterpreter.jl") end
        @safetestset "EGraphs Inequalities" begin include("test_inequality.jl") end
        @safetestset "Custom Types" begin include("test_custom_types.jl") end
        @safetestset "Fibonacci" begin include("fib/test_fibonacci.jl") end
        @safetestset "Calculational Logic" begin include("logic/test_calculational_logic.jl") end
        @safetestset "PROP Logic" begin include("logic/test_logic.jl") end
        @safetestset "CAS Infer" begin include("cas/test_infer.jl") end
        @safetestset "Knuth Bendix Alternative Hurwitz Groups" begin include("test_kb_benchmark.jl") end
        
        
        # @safetestset "Boson" begin include("test_boson.jl") end
        # @safetestset "PatEquiv" begin include("test_patequiv.jl") end
        # @testset "EGraphs Multipattern" begin include("test_multipat.jl") end
        # @testset "PatAllTerm" begin include("test_patallterm.jl") end
        # use cases
        # @testset "Proofs" begin include("proof/test_proof.jl") end
        # @testset "CAS" begin include("cas/test_cas.jl") end
        # @safetestset "Categories" begin include("category/test_cat.jl") end
        # TODO n-ary splatvar
    end
end
   
# exported consistency test
for m ∈ [Metatheory, Metatheory.EGraphs, Metatheory.EGraphs.Schedulers]
   for i ∈ propertynames(m)
      xxx = getproperty(m, i)
   end
end