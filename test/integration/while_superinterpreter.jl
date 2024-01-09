
# # Turing Complete Interpreter

using Metatheory, Test

include(joinpath(dirname(pathof(Metatheory)), "../examples/while_superinterpreter_theory.jl"))

@testset "Reading Memory" begin
  ex = :((x), $(Mem(:x => 2)))
  @test true == areequal(read_mem, ex, 2)
end

@testset "Arithmetic" begin
  @test areequal(read_mem ∪ arithm_rules, :((2 + 3), $(Mem())), 5)
end


@testset "Booleans" begin
  t = read_mem ∪ arithm_rules ∪ bool_rules

  @test areequal(t, :((false || false), $(Mem())), false)

  exx = :((false || false) || !(false || false), $(Mem(:x => 2)))
  g = EGraph(exx)
  saturate!(g, t)
  ex = extract!(g, astsize)
  @test ex == true
  params = SaturationParams(timeout = 12)
  @test areequal(t, exx, true; params = params)

  @test areequal(t, :((2 < 3) && (3 < 4), $(Mem(:x => 2))), true)
  @test areequal(t, :((2 < x) || !(3 < 4), $(Mem(:x => 2))), false)
  @test areequal(t, :((2 < x) || !(3 < 4), $(Mem(:x => 4))), true)
end

@testset "If Semantics" begin
  @test areequal(if_language, :(if true
    x
  else
    0
  end, $(Mem(:x => 2))), 2)
  @test areequal(if_language, :(if false
    x
  else
    0
  end, $(Mem(:x => 2))), 0)
  @test areequal(if_language, :(if !(false)
    x
  else
    0
  end, $(Mem(:x => 2))), 2)
  params = SaturationParams(timeout = 10)
  @test areequal(if_language, :(if !(2 < x)
    x
  else
    0
  end, $(Mem(:x => 3))), 0; params = params)
end

@testset "While Semantics" begin
  exx = :((x = 3), $(Mem(:x => 2)))
  g = EGraph(exx)
  saturate!(g, while_language)
  @test Mem(:x => 3) == extract!(g, astsize)


  exx = :((x = 4; x = x + 1), $(Mem(:x => 3)))
  g = EGraph(exx)
  saturate!(g, while_language)
  @test Mem(:x => 5) == extract!(g, astsize)


  params = SaturationParams(timeout = 14, timer = false)
  exx = :((
    if x < 10
      x = x + 1
    else
      skip
    end
  ), $(Mem(:x => 3)))
  @test areequal(while_language, exx, Mem(:x => 4); params = params)

  exx = :((while x < 10
    x = x + 1
  end;
  x), $(Mem(:x => 3)))
  g = EGraph(exx)
  params = SaturationParams(timeout = 250)
  saturate!(g, while_language, params)
  @test 10 == extract!(g, astsize)
end

