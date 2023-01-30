# ENV["JULIA_DEBUG"] = Metatheory
using Metatheory

function fib end

fibo = @theory x y n begin
  x::Int + y::Int => x + y
  fib(n::Int) => (n < 2 ? n : :(fib($(n - 1)) + fib($(n - 2))))
end

params = SaturationParams(timeout = 60)
g = EGraph(:(fib(10)))
@time saturate!(g, fibo, params)

z = EGraph(:(fib(10)))
@time saturate!(z, fibo, params)

@testset "Fibonacci" begin
  @test 55 == extract!(g, astsize)
end
