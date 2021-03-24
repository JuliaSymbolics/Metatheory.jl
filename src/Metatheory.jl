module Metatheory

using RuntimeGeneratedFunctions
using Base.Meta

include("docstrings.jl")

RuntimeGeneratedFunctions.init(@__MODULE__)

include("options.jl")

macro log(args...)
    quote options.verbose && @info($(args...)) end |> esc
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

include("Rules/Rules.jl")
using .Rules
export Rules
# TODO re-export? ugly?
include("Rules/exports.jl")

include("Classic/Classic.jl")
using .Classic: gettheory
export Classic

include("EGraphs/EGraphs.jl")
export EGraphs

include("Library/Library.jl")
export Library

end # module
