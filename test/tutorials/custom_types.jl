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
using TermInterface

# We first define our custom expression type in `MyExpr`:
struct MyExpr
  head::Any
  args::Vector{Any}
  foo::String # additional metadata
end
MyExpr(op, args) = MyExpr(op, args, "")
MyExpr(op) = MyExpr(op, [])

# We also need to define equality for our expression.
function Base.:(==)(a::MyExpr, b::MyExpr)
  a.head == b.head && a.args == b.args && a.foo == b.foo
end

# ## Overriding `TermInterface`` methods

# First, we need to discern when an expression is a leaf or a tree node.
# We can do it by overriding `isexpr`.
TermInterface.isexpr(::MyExpr) = true
# By default, our expression trees always represent a function call
TermInterface.iscall(::MyExpr) = true

# The `head` function tells us what's the node's represented operation. 
TermInterface.head(e::MyExpr) = e.head
# `children` tells the system how to extract the children nodes.
TermInterface.children(e::MyExpr) = e.args

# `operation` and `arguments` are functions used by the pattern matcher, required 
# when `iscall` is true on an expression. Since our custom expression type 
# **always represents function calls**, we can just define them to be `head` and `children`.
TermInterface.operation(e::MyExpr) = head(e)
TermInterface.arguments(e::MyExpr) = children(e)

# While for common usage you will always define `iscall` to be `true`, 
# there are some cases where you would like to match your expression types 
# against more complex patterns that are not function calls, for example, to match an expression `x` against an `a[b]` kind of pattern, 
# you would need to inform the system that `iscall` is `false`, and that its operation can match against `:ref` or `getindex` because 
ex = :(a[b])
(ex.head, ex.args)


# `metadata` should return the extra metadata. If you have many fields, i suggest using a `NamedTuple`.
# TermInterface.metadata(e::MyExpr) = e.foo

# struct MetadataAnalysis 
#   metadata
# end

# function EGraphs.make(g::EGraph{MyExprHead,MetadataAnalysis}, n::VecExpr) = 

# Additionally, you can override `EGraphs.preprocess` on your custom expression 
# to pre-process any expression before insertion in the E-Graph. 
# In this example, we always `uppercase` the `foo::String` field of `MyExpr`.
EGraphs.preprocess(e::MyExpr) = MyExpr(e.head, e.args, uppercase(e.foo))


# `TermInterface` provides a very important function called `maketerm`. 
# It is used to create a term that is in the same closure of types of `x`. 
# Given an existing head `h`, it is used to  instruct Metatheory how to recompose 
# a similar expression, given some children in `c` 
# and additionally, `metadata` and `type`, in case you are recomposing an `Expr`.
TermInterface.maketerm(::Type{MyExpr}, h, c, type = nothing, metadata = nothing) =
  MyExpr(h, c, isnothing(metadata) ? "" : metadata)

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
g = EGraph{MyExpr}(ex)

# Now let's test that it works.
saturate!(g, t)

# TODO metadata
# expected = MyExpr(:f, [MyExpr(:h, [4], "HELLO")], "")
expected = MyExpr(:f, [MyExpr(:h, [4], "")], "")

extracted = extract!(g, astsize)
@test expected == extracted


