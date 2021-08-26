using Metatheory
using Metatheory.EGraphs
using Metatheory.Library
using Metatheory.Util

using SymbolicUtils
using SymbolicUtils.Rewriters

function rewrite(expr, theory; order=:outer)
   if order == :inner 
      Fixpoint(Prewalk(Fixpoint(Chain(theory))))(expr)
   elseif order == :outer 
      Fixpoint(Postwalk(Fixpoint(Chain(theory))))(expr)
   end
end

# using DataStructures
using Test

Metatheory.options.verbose = false
Metatheory.options.printiter = false

@metatheory_init


falseormissing(x) = 
    x === missing || !x


@timev begin
   @testset "EGraphs Basics" begin include("test_egraphs.jl") end
   @testset "EMatch" begin include("test_ematch.jl") end
   @testset "EMatch Assertions" begin include("test_ematch_assertions.jl") end
   @testset "EGraph Analysis" begin include("test_analysis.jl") end
   @testset "EGraph Extraction" begin include("test_extraction.jl") end
   @testset "EGraphs Dynamic Rules" begin include("test_dynamic_ematch.jl") end
   @testset "Mu Puzzle" begin include("test_mu.jl") end
   @testset "Boson" begin include("test_boson.jl") end
   @testset "While Interpreter" begin include("test_while_interpreter.jl") end
   @testset "Classical Rewriting" begin include("test_reductions.jl") end
   @testset "Taylor Series" begin include("test_taylor.jl") end
   @testset "While Superinterpreter" begin include("test_while_superinterpreter.jl") end
   @testset "EGraphs Inequalities" begin include("test_inequality.jl") end
   @testset "PatEquiv" begin include("test_patequiv.jl") end
   @testset "Custom Types" begin include("test_custom_types.jl") end
   # @testset "EGraphs Multipattern" begin include("test_multipat.jl") end
   # @testset "PatAllTerm" begin include("test_patallterm.jl") end
   # use cases
   @testset "Fibonacci" begin include("fib/test_fibonacci.jl") end
   @testset "Calculational Logic" begin include("logic/test_calculational_logic.jl") end
   @testset "PROP Logic" begin include("logic/test_logic.jl") end
   @testset "CAS Infer" begin include("cas/test_infer.jl") end
   # @testset "CAS" begin include("cas/test_cas.jl") end
   @testset "Categories" begin include("category/test_cat.jl") end
   @testset "Knuth Bendix Alternative Hurwitz Groups" begin include("group/test_kb_benchmark.jl") end
   # @testset "Proofs" begin include("proof/test_proof.jl") end
   # TODO n-ary splatvar
   

   # exported consistency test
   for m ∈ [Metatheory, Metatheory.Util, Metatheory.EGraphs, Metatheory.EGraphs.Schedulers]
      for i ∈ propertynames(m)
         xxx = getproperty(m, i)
      end
   end
end
