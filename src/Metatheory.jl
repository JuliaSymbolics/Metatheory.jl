module Metatheory

using Base.Meta
using Reexport
using TermInterface

macro log(args...)
    quote haskey(ENV, "MT_DEBUG") && @info($(args...)) end |> esc
end

@inline alwaystrue(x) = true

include("docstrings.jl")
include("utils.jl")
export @matchable
include("Patterns.jl")
include("ematch_compiler.jl")
include("Rules/Rules.jl")
@reexport using .Rules
include("NewSyntax.jl")
include("SUSyntax.jl")
include("EGraphs/EGraphs.jl")
include("Library.jl")
include("Rewriters.jl")


@reexport using .Patterns 
@reexport using .EMatchCompiler
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
