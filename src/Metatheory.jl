"""
    Metatheory

Term-rewriting and equality-saturation tools for symbolic expressions.

The public interface is organized into [`Patterns`](@ref), [`Rules`](@ref),
[`Rewriters`](@ref), and [`EGraphs`](@ref). Construct patterns and rules with
the syntax macros, then use [`rewrite`](@ref) for ordinary rewriting or
[`EGraphs.saturate!`](@ref) for equality saturation.
"""
module Metatheory

using DataStructures

using Base.Meta
using Reexport
using TermInterface
using PrecompileTools: @compile_workload, @setup_workload

@inline alwaystrue(x) = true

function lookup_pat end
function maybelock! end

include("docstrings.jl")
include("utils.jl")
export @timer
export @iftimer
export @timerewrite
export @matchable

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
import .EGraphs: in_same_set
@reexport using .EGraphs

include("Library.jl")
export Library

include("Rewriters.jl")
using .Rewriters
export Rewriters

"""
    rewrite(expr, theory; order=:outer)

Repeatedly apply `theory` to an expression using tree traversal.

# Arguments

- `expr`: Expression or TermInterface-compatible tree to rewrite.
- `theory`: Iterable of callable rewrite rules.

# Keyword Arguments

- `order::Symbol=:outer`: Use `:outer` for post-order rewriting or `:inner`
  for pre-order rewriting.

The function preserves the input when a rule does not apply. Use
[`EGraphs.saturate!`](@ref) when all equivalent forms should be retained.
"""
function rewrite(expr, theory; order = :outer)
  if order == :inner
    Fixpoint(Prewalk(Fixpoint(Chain(theory))))(expr)
  elseif order == :outer
    Fixpoint(Postwalk(Fixpoint(Chain(theory))))(expr)
  end
end
export rewrite

include("precompile.jl")

end # module
