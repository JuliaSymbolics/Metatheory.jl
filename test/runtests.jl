using SafeTestsets
using Metatheory
using Test

function test(file::String)
  @info file
  @eval @time @safetestset $file begin
    include(joinpath(@__DIR__, $file))
  end
end

const TEST_FILES = ["reductions.jl", "EGraphs/egraphs.jl", "EGraphs/ematch.jl", "EGraphs/analysis.jl"]
const INTEGRATION_TEST_FILES = map(
  x -> joinpath("integration", x),
  [
    "custom_types.jl",
    "fibonacci.jl",
    "kb_benchmark.jl",
    "logic.jl",
    "mu.jl",
    "stream_fusion.jl",
    "taylor.jl",
    "while_interpreter.jl",
    "while_superinterpreter.jl",
  ],
)

@timev begin
  @timev map(test, TEST_FILES)
  @timev map(test, INTEGRATION_TEST_FILES)
end

# TODO: use Aqua.jl
# exported consistency test
for m in [Metatheory, Metatheory.EGraphs, Metatheory.EGraphs.Schedulers]
  for i in propertynames(m)
    xxx = getproperty(m, i)
  end
end
