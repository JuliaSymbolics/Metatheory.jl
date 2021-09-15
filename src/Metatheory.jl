module Metatheory

using Base.Meta
using Reexport

include("docstrings.jl")


include("options.jl")

macro log(args...)
    quote options.verbose && @info($(args...)) end |> esc
end

@inline alwaystrue(x) = true

export options

include("Util/Util.jl")
using .Util
export Util

include("Patterns/Patterns.jl")
@reexport using .Patterns 

include("ematch_compiler.jl")
@reexport using .EMatchCompiler

include("Rules/Rules.jl")
@reexport using .Rules

include("NewSyntax/NewSyntax.jl")
include("SUSyntax/SUSyntax.jl")

include("EGraphs/EGraphs.jl")
@reexport using .EGraphs

include("Library/Library.jl")
export Library

include("Rewriters.jl")
using .Rewriters
export Rewriters

function rewrite(expr, theory; order=:outer)
    if order == :inner 
        Fixpoint(Prewalk(Fixpoint(Chain(theory))))(expr)
    elseif order == :outer 
      Fixpoint(Postwalk(Fixpoint(Chain(theory))))(expr)
    end
end
export rewrite


end # module
