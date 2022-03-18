using Test

# FIXME this is a hack to get the test to work.
if VERSION < v"1.9.0-DEV"
  include("cas_infer.jl")

  ex1 = :(cos(1 + 3.0) + 4 + (4 - 4im))
  ex2 = :("ciao" * 2)
  ex3 = :("ciao" * " mondo")

  @test ComplexF64 == infer(ex1)
  @test_throws MethodError infer(ex2)
  @test String == infer(ex3)
end


