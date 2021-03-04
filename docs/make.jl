using Documenter

include("../src/Metatheory.jl")

makedocs(modules = [Metatheory], sitename = "Metatheory.jl",
    pages = [
        "index.md"
        "theories.md"
        "egraphs.md"
        "analysis.md"
        "classic.md"
        "api.md"
    ])

deploydocs(repo = "github.com/0x0f0f0f/Metatheory.jl.git")
