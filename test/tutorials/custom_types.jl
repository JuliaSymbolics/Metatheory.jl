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

using Metatheory, Test
using Metatheory.EGraphs

# Custom expressions types in TermInterface are identified by their `head` type.
# They should store a single field that corresponds to Julia's `head` field of `Expr`.
# Don't worry, for simple symbolic expressions, it is fine to make it default to `:call`.
# You can inspect some head type symbols by `dump`-ing some Julia `Expr`s that you obtain with `quote`. 
struct MyExprHead
  head
end
TermInterface.head_symbol(meh::MyExprHead) = meh.head

# We first define our custom expression type in `MyExpr`:
# It behaves like `Expr`, but it adds some extra fields.
struct MyExpr
  op::Any
  args::Vector{Any}
  foo::String # additional metadata
end
MyExpr(op, args) = MyExpr(op, args, "")
MyExpr(op) = MyExpr(op, [])

# We also need to define equality for our expression.
function Base.:(==)(a::MyExpr, b::MyExpr)
  a.op == b.op && a.args == b.args && a.foo == b.foo
end

# ## Overriding `TermInterface`` methods

# First, we need to discern when an expression is a leaf or a tree node.
# We can do it by overriding `istree`.
TermInterface.istree(::MyExpr) = true

# The `head` function tells us two things: 1) what is the head type, that determines the expression type and 
# 2) what is its `head_symbol`, which is used for interoperability and pattern matching. 
# It is used to bridge our custom `MyExpr`
# type, together with the `Expr` functionality that is used in Metatheory rule syntax. 
# In this example we say that all expressions of type `MyExpr`, can be represented (and matched against) by 
# a pattern that is represented by a `:call` Expr. 
TermInterface.head(e::MyExpr) = MyExprHead(:call)
# The `operation` function tells us what's the node's represented operation. 
TermInterface.operation(e::MyExpr) = e.op
# `arguments` tells the system how to extract the children nodes.
TermInterface.arguments(e::MyExpr) = e.args
# The children function gives us everything that is "after" the head:
TermInterface.children(e::MyExpr) = [operation(e); arguments(e)]

# While for common usage you will always define `head_symbol` to be `:call`, 
# there are some cases where you would like to match your expression types 
# against more complex patterns, for example, to match an expression `x` against an `a[b]` kind of pattern, 
# you would need to inform the system that `head(x)` is `MyExprHead(:ref)`, because 
ex = :(a[b])
(ex.head, ex.args)


# `metadata` should return the extra metadata. If you have many fields, i suggest using a `NamedTuple`.
# TermInterface.metadata(e::MyExpr) = e.foo

# struct MetadataAnalysis 
#   metadata
# end

# function EGraphs.make(g::EGraph{MyExprHead,MetadataAnalysis}, n::ENode) = 

# Additionally, you can override `EGraphs.preprocess` on your custom expression 
# to pre-process any expression before insertion in the E-Graph. 
# In this example, we always `uppercase` the `foo::String` field of `MyExpr`.
EGraphs.preprocess(e::MyExpr) = MyExpr(e.op, e.args, uppercase(e.foo))


# `TermInterface` provides a very important function called `maketerm`. 
# It is used to create a term that is in the same closure of types of `x`. 
# Given an existing head `h`, it is used to  instruct Metatheory how to recompose 
# a similar expression, given some children in `children` 
# and additionally, `metadata` and `type`, in case you are recomposing an `Expr`.
TermInterface.maketerm(h::MyExprHead, children; type = Any, metadata = nothing) =
  MyExpr(first(children), children[2:end], isnothing(metadata) ? "" : metadata)

# ## Theory Example

# Note that terms in the RHS will inherit the type of terms in the LHS.

t = @theory a begin
  f(z(2), a) --> f(a)
end

# Let's create an example expression and e-graph  
hcall = MyExpr(:h, [4], "hello")
ex = MyExpr(:f, [MyExpr(:z, [2]), hcall])
# We use the first type parameter an existing e-graph to inform the system about 
# the *default* type of expressions that we want newly added expressions to have.  
g = EGraph{MyExprHead}(ex)

# Now let's test that it works.
saturate!(g, t)
# expected = MyExpr(:f, [MyExpr(:h, [4], "HELLO")], "")
expected = MyExpr(:f, [MyExpr(:h, [4], "")], "")

extracted = extract!(g, astsize)
@test expected == extracted


