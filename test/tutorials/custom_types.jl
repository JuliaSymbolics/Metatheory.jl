# # Interfacing with Metatheory.jl
# This section is for Julia package developers who may want to use the rule
# rewriting systems on their own expression types.
# ## Defining the interface
# 
# Metatheory.jl matchers can match any Julia object that implements an interface
# to traverse it as a tree. The interface in question, is defined in the
# [TermInterface.jl](https://github.com/JuliaSymbolics/TermInterface.jl) package.
# Its purpose is to provide a shared interface between various symbolic
# programming Julia packages.
# In particular, you should define methods from TermInterface.jl for an expression
# tree type `T` with symbol types `S` to work with SymbolicUtils.jl
# You can read the documentation of
# [TermInterface.jl](https://github.com/JuliaSymbolics/TermInterface.jl) on the
# [Github repository](https://github.com/JuliaSymbolics/TermInterface.jl).

# ## Concrete example

using Metatheory, TermInterface, Test
using Metatheory.EGraphs

# We first define our custom expression type in `MyExpr`:
# It behaves like `Expr`, but it adds some extra fields.
struct MyExpr
  head::Any
  args::Vector{Any}
  foo::String # additional metadata
end
MyExpr(head, args) = MyExpr(head, args, "")
MyExpr(head) = MyExpr(head, [])

# We also need to define equality for our expression.
function Base.:(==)(a::MyExpr, b::MyExpr)
  a.head == b.head && a.args == b.args && a.foo == b.foo
end

# ## Overriding `TermInterface`` methods

# First, we need to discern when an expression is a leaf or a tree node.
# We can do it by overriding `istree`.
TermInterface.istree(::MyExpr) = true

# The `operation` function tells us what's the node's represented operation. 
TermInterface.operation(e::MyExpr) = e.head
# `arguments` tells the system how to extract the children nodes.
TermInterface.arguments(e::MyExpr) = e.args

# A particular function is `exprhead`. It is used to bridge our custom `MyExpr`
# type, together with the `Expr` functionality that is used in Metatheory rule syntax. 
# In this example we say that all expressions of type `MyExpr`, can be represented (and matched against) by 
# a pattern that is represented by a `:call` Expr. 
TermInterface.exprhead(::MyExpr) = :call

# While for common usage you will always define `exprhead` it to be `:call`, 
# there are some cases where you would like to match your expression types 
# against more complex patterns, for example, to match an expression `x` against an `a[b]` kind of pattern, 
# you would need to inform the system that `exprhead(x)` is `:ref`, because 
ex = :(a[b])
(ex.head, ex.args)


# `metadata` should return the extra metadata. If you have many fields, i suggest using a `NamedTuple`.
TermInterface.metadata(e::MyExpr) = e.foo

# Additionally, you can override `EGraphs.preprocess` on your custom expression 
# to pre-process any expression before insertion in the E-Graph. 
# In this example, we always `uppercase` the `foo::String` field of `MyExpr`.
EGraphs.preprocess(e::MyExpr) = MyExpr(e.head, e.args, uppercase(e.foo))


# `TermInterface` provides a very important function called `similarterm`. 
# It is used to create a term that is in the same closure of types of `x`. 
# Given an existing term `x`, it is used to  instruct Metatheory how to recompose 
# a similar expression, given a `head` (the result of `operation`), some children (given by `arguments`) 
# and additionally, `metadata` and `exprehead`, in case you are recomposing an `Expr`.
function TermInterface.similarterm(x::MyExpr, head, args; metadata = nothing, exprhead = :call)
  MyExpr(head, args, isnothing(metadata) ? "" : metadata)
end

# Since `similarterm` works by making a new term similar to an existing term `x`, 
# in the e-graphs system, there won't be enough information such as a 'reference' object.
# Only the type of the object is known. This extra function adds a bit of verbosity, due to compatibility 
# with SymbolicUtils.jl
function EGraphs.egraph_reconstruct_expression(::Type{MyExpr}, op, args; metadata = nothing, exprhead = nothing)
  MyExpr(op, args, (isnothing(metadata) ? () : metadata))
end

# ## Theory Example

# Note that terms in the RHS will inherit the type of terms in the LHS.

t = @theory a begin
  f(z(2), a) --> f(a)
end

# Let's create an example expression and e-graph  
hcall = MyExpr(:h, [4], "hello")
ex = MyExpr(:f, [MyExpr(:z, [2]), hcall])
# We use `head_type` kwarg on an existing e-graph to inform the system about 
# the *default* type of expressions that we want newly added expressions to have.  
g = EGraph(ex; keepmeta = true, head_type = MyExpr)

# Now let's test that it works.
saturate!(g, t)
expected = MyExpr(:f, [MyExpr(:h, [4], "HELLO")], "")
extracted = extract!(g, astsize)
@test expected == extracted


