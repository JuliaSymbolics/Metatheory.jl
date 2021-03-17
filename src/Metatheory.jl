module Metatheory

using RuntimeGeneratedFunctions
using Base.Meta

include("docstrings.jl")

RuntimeGeneratedFunctions.init(@__MODULE__)

# TODO document options
# Options
options = Dict{Symbol, Any}(
    :verbose => false,
    :printiter => false,
)

macro log(args...)
    quote options[:verbose] && @info($(args...)) end |> esc
end

export options

include("Util/Util.jl")
using .Util
export Util

# TODO document this interface
include("TermInterface.jl")
using .TermInterface
export TermInterface

include("rgf.jl")
export @metatheory_init

include("rule.jl")
export Rule
export @rule
export RHS_FUNCTION_CACHE
export getrhsfun

include("theory.jl")
export @theory
export Theory

include("Classic/Classic.jl")
using .Classic: gettheory
export Classic

include("EGraphs/EGraphs.jl")
export EGraphs

include("Library/Library.jl")
export Library

end # module
