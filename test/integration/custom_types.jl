using Metatheory
using Metatheory.EGraphs
using TermInterface
using Test

struct MyExpr
  head::Any
  # NOTE! this will not work, when replacing 
  # with z in the theory defined below, the arg type 
  # will be EGraphs.EClass! Additional manipulation 
  # is needed for custom term types with stricter arg types
  # args::Vector{Union{Int, MyExpr}}
  args::Vector{Any}
  # additional metadata
  foo::String
  bar::Vector{Complex}
  baz::Set{Int}
end

import Base.(==)
(==)(a::MyExpr, b::MyExpr) = a.head == b.head && a.args == b.args && a.foo == b.foo && a.bar == b.bar && a.baz == b.baz

MyExpr(head, args) = MyExpr(head, args, "", Complex[], Set{Int}())
MyExpr(head) = MyExpr(head, [])

# Methods needed by `src/TermInterface.jl`
TermInterface.exprhead(e::MyExpr) = :call
TermInterface.operation(e::MyExpr) = e.head
TermInterface.arguments(e::MyExpr) = e.args
TermInterface.istree(e::MyExpr) = true
# NamedTuple
TermInterface.metadata(e::MyExpr) = (foo = e.foo, bar = e.bar, baz = e.baz)
EGraphs.preprocess(e::MyExpr) = MyExpr(e.head, e.args, uppercase(e.foo), e.bar, e.baz)

function TermInterface.similarterm(x::MyExpr, head, args; metadata = nothing, exprhead = :call)
  meta = isnothing(metadata) ? ("", Complex[], Set{Int64}()) : metadata
  MyExpr(head, args, meta...)
end

function EGraphs.egraph_reconstruct_expression(T::Type{MyExpr}, op, args; metadata = nothing, exprhead = nothing)
  MyExpr(op, args, (isnothing(metadata) ? () : metadata)...)
end


function f end 
function h end 
function z end

# let's create an example theory
t = @theory a begin
  # this way, z will be a regular expr
  # f(g(2), a) => z(a)
  # we can use dynamic rules to construct values of type MyExpr
  # f(g(2), a) |> MyExpr(:z, [a])

  # terms in the RHS inherit the type of terms in the lhs
  f(z(2), a) --> f(a)
end

# f(z(2), h(4)) with some metadata in h
hcall = MyExpr(h, [4], "hello", [2 + 3im, 4 + 2im], Set{Int}([4, 5, 6]))
# let's create an egraph 
ex = MyExpr(f, [MyExpr(:z, [2]), hcall])
g = EGraph(ex; keepmeta = true)
settermtype!(g, MyExpr)

saturate!(g, t)

# TODO test metadata

expected =
  MyExpr(f, [MyExpr(h, [4], "HELLO", Complex[2 + 3im, 4 + 2im], Set([5, 4, 6]))], "", Complex[], Set{Int64}())

extracted = extract!(g, astsize)

@test expected == extracted
