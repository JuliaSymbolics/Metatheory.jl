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
include("rule.jl")
export Rule

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


export rewrite
export @rewrite
export @esc_rewrite
export @compile_theory
export @matcher
export @rewriter

end # module
