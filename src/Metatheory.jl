module Metatheory

using Base.Meta
using Reexport

@inline alwaystrue(x) = true


function to_expr end
function has_constant end
function get_constant end
function lookup_pat end
function maybelock! end
export has_constant
export get_constant

include("docstrings.jl")

include("vecexpr.jl")
@reexport using .VecExprModule

const Bindings = Base.ImmutableDict{Int,Tuple{Id,Int}}
const UNDEF_ID_VEC = Vector{Id}(undef, 0)

include("utils.jl")
export @timer


include("TermInterface.jl")
@reexport using .TermInterface

include("Patterns.jl")
@reexport using .Patterns

include("ematch_compiler.jl")
@reexport using .EMatchCompiler

include("matchers.jl")
include("Rules.jl")
@reexport using .Rules

include("Syntax.jl")
@reexport using .Syntax
include("EGraphs/EGraphs.jl")
@reexport using .EGraphs

include("Library.jl")
export Library

include("Rewriters.jl")
using .Rewriters
export Rewriters

function rewrite(expr, theory; order = :outer)
  if order == :inner
    Fixpoint(Prewalk(Fixpoint(Chain(theory))))(expr)
  elseif order == :outer
    Fixpoint(Postwalk(Fixpoint(Chain(theory))))(expr)
  end
end
export rewrite


end # module
