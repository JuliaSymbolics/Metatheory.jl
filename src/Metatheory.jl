module Metatheory

using DataStructures

const DEFAULT_BUFFER_SIZE = 1024 * 1024 * 8
const BUFFER_T = CircularDeque{Tuple{Int,Int}}
const BUFFERS = Vector{Tuple{BUFFER_T,ReentrantLock}}(undef, Threads.nthreads())
const MERGES_BUF = Ref(BUFFER_T(DEFAULT_BUFFER_SIZE))
const MERGES_BUF_LOCK = ReentrantLock()

using Base.Meta
using Reexport
using TermInterface

macro log(args...)
  quote
    haskey(ENV, "MT_DEBUG") && @info($(args...))
  end |> esc
end

@inline alwaystrue(x) = true

function lookup_pat end

include("docstrings.jl")
include("utils.jl")
export @timer
export @iftimer
export @timerewrite
export @matchable

include("Patterns.jl")
@reexport using .Patterns

include("ematch_compiler_new.jl")
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
