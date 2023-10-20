# # Benchmarking Fibonacci. E-Graphs memoize computation.

using Metatheory
using Test

function fib end

fibo = @theory x y n begin
  x::Int + y::Int => x + y
  fib(n::Int) => (n < 2 ? n : :(fib($(n - 1)) + fib($(n - 2))))
end

params = SaturationParams(timeout = 60)

# We run the saturation twice to see a result that does not include compilation time.
g = EGraph(:(fib(10)))
saturate!(g, fibo, params)

# That's fast!
z = EGraph(:(fib(10)))
saturate!(z, fibo, params)

# We can test that the result is correct.
@testset "Fibonacci" begin
  @test 55 == extract!(g, astsize)
end
