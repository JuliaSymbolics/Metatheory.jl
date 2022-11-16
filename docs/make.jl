using Documenter
using Metatheory

using Metatheory.EGraphs
using Metatheory.Library

makedocs(
  modules = [Metatheory, Metatheory.EGraphs],
  sitename = "Metatheory.jl",
  pages = [
    "index.md"
    "rewrite.md"
    "egraphs.md"
    "interface.md"
    "api.md"
  ],
)

deploydocs(repo = "github.com/JuliaSymbolics/Metatheory.jl.git")
