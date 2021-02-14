module Metatheory

using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)


include("util.jl")
include("rule.jl")
include("theory.jl")
include("matchcore_compiler.jl")
include("rewrite.jl")
include("match.jl")
include("EGraphs/EGraphs.jl")


include("Library/Library.jl")
export Library

export @rule
export @theory

export Theory
export Rule


export rewrite
export @rewrite
export @esc_rewrite
export @compile_theory
export @matcher
export @rewriter

end # module
