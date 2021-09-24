using Documenter
using Metatheory

using Metatheory.EGraphs
using Metatheory.Library


for m ∈ [Metatheory]
    for i ∈ propertynames(m)
       xxx = getproperty(m, i)
       println(xxx)
    end
 end

makedocs(
    modules = [Metatheory],
    sitename = "Metatheory.jl",
    pages = [
        "index.md"
        "theories.md"
        "egraphs.md"
        "analysis.md"
        "extraction.md"
        "schedulers.md"
        "classic.md"
        "options.md"
    ])

deploydocs(repo = "github.com/0x0f0f0f/Metatheory.jl.git")
