module Metatheory

using DataStructures

import Base.ImmutableDict

const Bindings = ImmutableDict{Int,Tuple{Int,Int}}
const DEFAULT_BUFFER_SIZE = 1048576
const BUFFER = Ref(CircularDeque{Bindings}(DEFAULT_BUFFER_SIZE))
const BUFFER_LOCK = ReentrantLock()
const MERGES_BUF = Ref(CircularDeque{Tuple{Int,Int}}(DEFAULT_BUFFER_SIZE))
const MERGES_BUF_LOCK = ReentrantLock()

function resetbuffers!(bufsize)
  BUFFER[] = CircularDeque{Bindings}(bufsize)
  MERGES_BUF[] = CircularDeque{Tuple{Int,Int}}(bufsize)
end

function __init__()
  resetbuffers!(DEFAULT_BUFFER_SIZE)
end

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
