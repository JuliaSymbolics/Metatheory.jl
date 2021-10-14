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
    modules = [Metatheory, Metatheory.EGraphs],
    sitename = "Metatheory.jl",
    pages = [
        "index.md"
        "rewrite.md"
        "egraphs.md"
        "interface.md"
        "api.md"
    ])

deploydocs(repo = "github.com/JuliaSymbolics/Metatheory.jl.git")
