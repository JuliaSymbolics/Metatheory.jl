module Metatheory

using RuntimeGeneratedFunctions
using Base.Meta

include("docstrings.jl")

RuntimeGeneratedFunctions.init(@__MODULE__)

# TODO document this interface
include("expr_abstraction.jl")
export iscall
export getfunsym
export getfunargs
export setfunsym!
export setfunargs!

include("Util/Util.jl")
using .Util
export Util


include("rgf.jl")
include("rule.jl")
include("theory.jl")
include("matchcore_compiler.jl")
include("rewrite.jl")
include("match.jl")



include("EGraphs/EGraphs.jl")
export EGraphs

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
