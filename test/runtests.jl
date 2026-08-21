using SafeTestsets
using Documenter
using Metatheory
using SciMLTesting
using Test

struct ContractGoal <: Metatheory.EGraphs.SaturationGoal end
Metatheory.EGraphs.reached(::Metatheory.EGraphs.EGraph, ::ContractGoal) = true
struct ContractRule <: Metatheory.Rules.AbstractRule end

mutable struct ContractScheduler <: Metatheory.EGraphs.Schedulers.AbstractScheduler
  iteration::Int
end

ContractScheduler(::Metatheory.EGraphs.EGraph, ::Vector{<:Metatheory.Rules.AbstractRule}) = ContractScheduler(0)
Metatheory.EGraphs.Schedulers.cansaturate(::ContractScheduler) = false
Metatheory.EGraphs.Schedulers.cansearch(::ContractScheduler, ::Metatheory.Rules.AbstractRule) = true
Metatheory.EGraphs.Schedulers.inform!(::ContractScheduler, ::Metatheory.Rules.AbstractRule, ::Int) = true
Metatheory.EGraphs.Schedulers.setiter!(scheduler::ContractScheduler, iteration) = scheduler.iteration = iteration

function run_core_tests()
  doctest(Metatheory)

  @testset "Generic interface contracts" begin
    g = Metatheory.EGraphs.EGraph(1)
    goal = ContractGoal()
    @test Metatheory.EGraphs.reached(g, goal)

    params = Metatheory.EGraphs.SaturationParams(goal = goal, scheduler = ContractScheduler, timeout = 2, timer = false)
    report = Metatheory.EGraphs.saturate!(g, Metatheory.Rules.AbstractRule[], params)
    @test report.reason === :goalreached
    @test report.iterations == 1

    scheduler = ContractScheduler(0)
    rule = ContractRule()
    @test Metatheory.EGraphs.Schedulers.cansearch(scheduler, rule)
    @test Metatheory.EGraphs.Schedulers.inform!(scheduler, rule, 0)
    Metatheory.EGraphs.Schedulers.setiter!(scheduler, 3)
    @test scheduler.iteration == 3
  end

  function test(file::String)
    @info file
    @eval @time @safetestset $file begin
      include(joinpath(@__DIR__, $file))
    end
  end

  allscripts(dir) = [joinpath(@__DIR__, dir, x) for x in readdir(dir) if endswith(x, ".jl")]

  test_files = [
    allscripts("classic")
    allscripts("egraphs")
    allscripts("integration")
    allscripts("tutorials")
  ]

  @timev map(test, test_files)

  # exported consistency test
  for m in [Metatheory, Metatheory.EGraphs, Metatheory.EGraphs.Schedulers]
    for i in propertynames(m)
      !hasproperty(m, i) && error("Module $m exports undefined symbol $i")
    end
  end
end

run_tests(core = run_core_tests, qa = (; env = joinpath(@__DIR__, "qa"), body = joinpath(@__DIR__, "qa", "qa.jl")))
