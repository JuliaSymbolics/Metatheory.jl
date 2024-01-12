"""
This module defines a contains definitions for common functions that are useful for symbolic expression manipulation.
Its purpose is to provide a shared interface between various symbolic programming Julia packages.

This is currently borrowed from TermInterface.jl. 
If you want to use Metatheory.jl, please use this internal interface, as we are waiting that 
a redesign proposal of the interface package will reach consensus. When this happens, this module 
will be moved back into a separate package.

See https://github.com/JuliaSymbolics/TermInterface.jl/pull/22
"""
module TermInterface

"""
  istree(x)

Returns `true` if `x` is a term. If true, `operation`, `arguments`
must also be defined for `x` appropriately.
"""
istree(x) = false
export istree

"""
  symtype(x)

Returns the symbolic type of `x`. By default this is just `typeof(x)`.
Define this for your symbolic types if you want `SymbolicUtils.simplify` to apply rules
specific to numbers (such as commutativity of multiplication). Or such
rules that may be implemented in the future.
"""
function symtype(x)
  typeof(x)
end
export symtype


"""
  head(x)

If `x` is a term as defined by `istree(x)`, `head(x)` returns the head of the
term if `x`. The `head` type has to be provided by the package.
if `x` represents a function call, for example, the head
is the function being called.
"""
function head end
export head


"""
  children(x)

Get the arguments of `x`, must be defined if `istree(x)` is `true`.
"""
function children end
export children

"""
  arity(x)

Returns the number of children of `x`. Implicitly defined 
if `children(x)` is defined.
"""
arity(x)::Int = length(children(x))
export arity


"""
  metadata(x)

Return the metadata attached to `x`.
"""
function metadata(x) end
export metadata


"""
  metadata(x, md)

Returns a new term which has the structure of `x` but also has
the metadata `md` attached to it.
"""
function metadata(x, data) end


"""
  maketerm(T::Type, children; type=Any, metadata=nothing)

Has to be implemented by the provider of T.
Returns a term that is in the same closure of types as `typeof(x)`,
with `head` as the head and `children` as the arguments, `type` as the symtype
and `metadata` as the metadata. 
"""
function maketerm end
export maketerm

"""
  is_operation(f)

Returns a single argument anonymous function predicate, that returns `true` if and only if
the argument to the predicate satisfies `istree` and `head(x) == f` 
"""
is_head(f) = @nospecialize(x) -> istree(x) && (head(x) == f)
export is_head


"""
  node_count(t)
Count the nodes in a symbolic expression tree satisfying `istree` and `arguments`.
"""
node_count(t) = istree(t) ? reduce(+, node_count(x) for x in children(t), init in 0) + 1 : 1
export node_count

""" 
  @matchable struct Foo fields... end [HeadType]

Take a struct definition and automatically define `TermInterface` methods. 
`is_function_call` of such type will default to `true`.
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
    # TODO default to call?
    TermInterface.istree(::$name) = true
    TermInterface.is_function_call(::$name) = true
    TermInterface.head(::$name) = $name
    TermInterface.children(x::$name) = getfield.((x,), ($(QuoteNode.(fields)...),))
    TermInterface.arity(x::$name) = $(length(fields))
    Base.length(x::$name) = $(length(fields) + 1)
  end |> esc
end
export @matchable

# ------------------------------
# ## Traits
"""

Should return `true`` only if `istree(x)` is `true`.
"""
is_function_call(x) = false
export is_function_call

# This file contains default definitions for TermInterface methods on Julia
# Builtin Expr type.

is_function_call(e::Expr) = _is_function_call_expr_head(e.head)
_is_function_call_expr_head(x::Symbol) = x in (:call, :macrocall)

istree(x::Expr) = true

# See https://docs.julialang.org/en/v1/devdocs/ast/
head(e::Expr) = is_function_call(e) ? e.args[1] : e.head
children(e::Expr) = is_function_call(e) ? e.args[2:end] : e.args

function arity(e::Expr)::Int
  l = length(e.args)
  is_function_call(e) ? l - 1 : l
end

function maketerm(T::Type{Expr}, head::Symbol, children; is_call = true, type = Any, metadata = nothing)
  if is_call
    Expr(:call, head, children...)
  else
    Expr(head, children...)
  end
end

# TODO is this needed?
maketerm(T::Type{Expr}, head::Union{Function,DataType}, children; is_call = true, type = Any, metadata = nothing) =
  maketerm(T, nameof(head), children; is_call, type, metadata)


end # module

