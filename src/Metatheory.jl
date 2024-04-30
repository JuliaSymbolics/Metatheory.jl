module Metatheory

using Base.Meta
using Reexport

@inline alwaystrue(x...) = true

function to_expr end
function has_constant end
function get_constant end
function lookup_pat end
export has_constant
export get_constant

# TODO: document
function should_quote_operation end
should_quote_operation(::Function) = true
should_quote_operation(x) = false

include("docstrings.jl")

include("vecexpr.jl")
@reexport using .VecExprModule

const UNDEF_ID_VEC = Vector{Id}(undef, 0)

using TermInterface
using TermInterface: isexpr

""" 
  @matchable struct Foo fields... end [HeadType]

Take a struct definition and automatically define `TermInterface` methods. 
`iscall` of such type will default to `true`.
"""
macro matchable(expr)
  @assert expr.head == :struct
  name = expr.args[2]
  if name isa Expr
    name.head === :(<:) && (name = name.args[1])
    name isa Expr && name.head === :curly && (name = name.args[1])
  end
  fields = filter(x -> x isa Symbol || (x isa Expr && x.head == :(::)), expr.args[3].args)
  get_name(s::Symbol) = s
  get_name(e::Expr) = (@assert(e.head == :(::)); e.args[1])
  fields = map(get_name, fields)

  quote
    $expr
    TermInterface.isexpr(::$name) = true
    TermInterface.iscall(::$name) = true
    TermInterface.head(::$name) = $name
    TermInterface.operation(::$name) = $name
    TermInterface.children(x::$name) = getfield.((x,), ($(QuoteNode.(fields)...),))
    TermInterface.arguments(x::$name) = TermInterface.children(x)
    TermInterface.arity(x::$name) = $(length(fields))
    Base.length(x::$name) = $(length(fields) + 1)
  end |> esc
end
export @matchable

include("utils.jl")
export @timer


include("Patterns.jl")
@reexport using .Patterns

include("ematch_compiler.jl")
export ematch_compile

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
