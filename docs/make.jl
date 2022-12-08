using Documenter
using Metatheory
using Literate

using Metatheory.EGraphs
using Metatheory.Library

TUTORIALSDIR = joinpath(dirname(pathof(Metatheory)), "../test/tutorials/")
OUTDIR = abspath(joinpath(@__DIR__, "src", "tutorials"))

for f in readdir(TUTORIALSDIR)
  if endswith(f, ".jl")
    input = abspath(joinpath(TUTORIALSDIR, f))
    name = basename(input)
    Literate.markdown(input, OUTDIR)
  elseif f != "README.md"
    @info "Copying $f"
    cp(joinpath(TUTORIALSDIR, input), joinpath(OUTDIR, f); force=true)
  end
end

tutorials = [joinpath("tutorials", f[1:end-3]) * ".md" for f in readdir(TUTORIALSDIR) if endswith(f, ".jl")]

makedocs(
  modules = [Metatheory, Metatheory.EGraphs],
  sitename = "Metatheory.jl",
  pages = [
    "index.md"
    "rewrite.md"
    "egraphs.md"
    "interface.md"
    "api.md"
    "Tutorials" => tutorials
  ],
)

#deploydocs(repo = "github.com/JuliaSymbolics/Metatheory.jl.git")
