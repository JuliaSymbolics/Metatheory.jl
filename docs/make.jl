using Documenter

include("../src/Metatheory.jl")

makedocs(modules = [Metatheory], sitename = "Metatheory.jl")

deploydocs(repo = "github.com/0x0f0f0f/Metatheory.jl.git")
