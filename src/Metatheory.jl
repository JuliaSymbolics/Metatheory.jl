module Metatheory

using Base.Meta
using Reexport
using TermInterface

macro log(args...)
    quote options.verbose && @info($(args...)) end |> esc
end

@inline alwaystrue(x) = true

include("docstrings.jl")
include("options.jl")
include("util.jl")
include("Patterns/Patterns.jl")
include("ematch_compiler.jl")
include("Rules/Rules.jl")
include("NewSyntax/NewSyntax.jl")
include("SUSyntax/SUSyntax.jl")
include("EGraphs/EGraphs.jl")
include("Library/Library.jl")
include("Rewriters/Rewriters.jl")


export options
@reexport using .Patterns 
@reexport using .EMatchCompiler
@reexport using .Rules
@reexport using .EGraphs
export Library
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
