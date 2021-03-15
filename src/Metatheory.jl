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
    :sizeout => 2^14, # default sizeout
    :timeout => 7,
    :matchlimit => 5000
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
include("theory.jl")
export Rule
export @rule
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
