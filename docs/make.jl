using Documenter
using Metatheory
using Literate

using Metatheory.EGraphs
using Metatheory.Library

const METATHEORY_PATH = dirname(pathof(Metatheory))
const TUTORIALS_DIR = joinpath(METATHEORY_PATH, "../test/tutorials/")
const EXAMPLES_DIR = joinpath(METATHEORY_PATH, "../examples/")
const OUTDIR = abspath(joinpath(@__DIR__, "src", "tutorials"))

function replace_includes(str)
  for f in readdir(EXAMPLES_DIR)
    content = read(joinpath(EXAMPLES_DIR, f), String)
    str = replace(str, "include(joinpath(dirname(pathof(Metatheory)), \"../examples/$(f)\"))" => content)
  end
  return str
end

# Generate markdown document using Literate.jl for each file in the tutorials directory. 
for f in readdir(TUTORIALS_DIR)
  if endswith(f, ".jl")
    input = abspath(joinpath(TUTORIALS_DIR, f))
    name = basename(input)
    Literate.markdown(input, OUTDIR, preprocess = replace_includes)
  elseif f != "README.md"
    @info "Copying $f"
    cp(joinpath(TUTORIALS_DIR, input), joinpath(OUTDIR, f); force = true)
  end
end

tutorials = [joinpath("tutorials", f[1:(end - 3)]) * ".md" for f in readdir(TUTORIALS_DIR) if endswith(f, ".jl")]

makedocs(
  modules = [Metatheory, Metatheory.EGraphs],
  sitename = "Metatheory.jl",
  pages = [
    "index.md"
    "rewrite.md"
    "egraphs.md"
    "visualizing.md"
    "api.md"
    "Tutorials" => tutorials
  ],
)

deploydocs(repo = "github.com/JuliaSymbolics/Metatheory.jl.git")
