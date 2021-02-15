module Metatheory

using RuntimeGeneratedFunctions
using Base.Meta

RuntimeGeneratedFunctions.init(@__MODULE__)


include("Util/Util.jl")
using .Util



include("rule.jl")
include("theory.jl")
include("matchcore_compiler.jl")
include("rewrite.jl")
include("match.jl")
include("EGraphs/EGraphs.jl")

export @metatheory_init

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
