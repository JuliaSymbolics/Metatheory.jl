using SafeTestsets
using Documenter
using Metatheory
using Test

# doctest(Metatheory)

function test(file::String)
  @info file
  @eval @time @safetestset $file begin
    include(joinpath(@__DIR__, $file))
  end
end

allscripts(dir) = [joinpath(@__DIR__, dir, x) for x in readdir(dir) if endswith(x, ".jl")]

const TEST_FILES = [
  allscripts("unit")
  allscripts("classic")
  allscripts("egraphs")
  allscripts("integration")
  allscripts("tutorials")
]

@timev map(test, TEST_FILES)

# exported consistency test
for m in [Metatheory, Metatheory.EGraphs, Metatheory.EGraphs.Schedulers]
  for i in propertynames(m)
    !hasproperty(m, i) && error("Module $m exports undefined symbol $i")
  end
end
