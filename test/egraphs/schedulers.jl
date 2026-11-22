using Metatheory
using Test

@testset "Backoff uses per-rule match counts" begin
  theory = @theory x begin
    f(x) --> g(x)
    g(x) --> h(x)
  end
  graph = EGraph(:(pair(f(a), g(b))))
  source = addexpr!(graph, :(f(a)))
  target = addexpr!(graph, :(h(a)))
  params = SaturationParams(timeout = 2, schedulerparams = (1, 5))
  saturate!(graph, theory, params)
  @test in_same_class(graph, source, target)
end
