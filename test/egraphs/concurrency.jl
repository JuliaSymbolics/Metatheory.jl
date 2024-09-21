# MT currently does not support thread-parallel saturation with a shared state.
# But it should be possible to saturate independent egraphs withing separate threads.

using Test, Metatheory

function run_eq()
    theory = @theory a b c begin
              a + b == b + a
              a + (b + c) == (a + b) + c
    end
  
    g = EGraph{Expr}(:(1 + (2 + (3 + (4 + (5 + 6))))));
    saturate!(g, theory, SaturationParams(timeout=100))
  end
  
  function test_threads()
      @assert Threads.threadpoolsize() > 1 # this test is only useful in multi-threaded scenarios.
      
      # run equality saturation in parallel threads (no shared state)
      Threads.@threads for _ in 1:1000
          run_eq()
      end
      true
  end

@testset "Concurrency" begin
    @test test_threads()
end