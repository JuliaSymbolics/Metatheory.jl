using Metatheory, Test, TermInterface

# # Lambda theory
#
# This tutorial demonstrates how to implement a simple lambda calculus in Metatheory.
# Importantly, it shows a practical example of [*e-graph analysis*](/egraphs/#EGraph-Analyses).
# The three building blocks of lambda caluclus are *variables*, $\lambda$-functions, and *function
# application*, which we can implement as subtypes of an abstract `LambdaExpr`ession:

abstract type LambdaExpr end

@matchable struct Variable <: LambdaExpr
  x
end
Base.show(io::IO, x::Variable) = print(io, "$(x.x)")

@matchable struct λ <: LambdaExpr
  x
  body
end
Base.show(io::IO, x::λ) = print(io, "λ$(x.x).($(x.body))")

@matchable struct Apply <: LambdaExpr
  lambda
  value
end
Base.show(io::IO, x::Apply) = print(io, "($(x.lambda))($(x.value))")

# With the above we can construct arbitrary lambda expressions:

x = Variable(:x)
λ(:x, Apply(x,x))

# The $\beta$-reduction can be implemented via an additional type `Let`. To get started we can ignore
# the cases where we need $\alpha$-conversion and already implement 

@matchable struct Let <: LambdaExpr
  variable
  value
  body
end
Base.show(io::IO, x::Let) = print(io, "$(x.body)[$(x.variable) := $(x.value)]")

λT = @theory v e c v1 v2 a b body begin
  Let(v, e, c::Any) --> c # let-const
  Let(v1, e, Variable(v1)) --> e # let-Variable-same
  Let(v1, e, Variable(v2)) => v1 == v2 ? e : Variable(v2) # let-Variable-diff
  Let(v1, e, λ(v1, body)) --> λ(v1, body) # let-lam-same
  Apply(λ(v, body), e) --> Let(v, e, body) # beta reduction
  Let(v, e, Apply(a, b)) --> Apply(Let(v, e, a), Let(v, e, b)) # let-Apply
end

x = Variable(:x)
y = Variable(:y)
ex = Apply(λ(:x, λ(:y, Apply(x,y))), y)
g = EGraph(ex)
saturate!(g, λT)
extract!(g, astsize)


# Unfortunately, the above does not correctly rename variables when needed. To correctly
# implement $\alpha$-conversion we need to keep track of free and bound variables in each eclass.
# Essentially, we want to add a rule to our theory which reads:
#
# ```julia
# Let(v1, e, λ(v2, body)) => if isfree(_egraph,e,v2)
#   fresh = freshvar()
#   λ(fresh, Let(v1, e, Let(v2, Variable(fresh), body)))
# else
#   λ(v2, Let(v1, e, body))
# end
# ```
#
# where we want to be able to check if a variable is free:

function isfree(g::EGraph, eclass, var)
  @assert length(var.nodes)==1
  var_sym = get_constant(g, v_head(var.nodes[1]))
  @assert var_sym isa Symbol
  var_sym ∈ getdata(eclass)
end

# This can be done via an `Analysis` datastructure which we can include in an
# `EClass`. We overload Egraphs.make such that whenever we add a new enode to
# the egraph we keep track of the free variables.

const LambdaAnalysis = Set{Symbol}

getdata(eclass) = isnothing(eclass.data) ? LambdaAnalysis() : eclass.data

function EGraphs.make(g::EGraph{ExprType,LambdaAnalysis}, n::VecExpr) where ExprType
  v_isexpr(n) || LambdaAnalysis()
  if v_iscall(n)
    h = v_head(n)
    op = get_constant(g, h)
    args = v_children(n)
    eclass = g[args[1]]
    free = getdata(eclass)

    if op == Variable
      push!(free, get_constant(g, v_head(eclass.nodes[1])))

    elseif op == Let
      v, a, b = args[1:3]
      adata = getdata(g[a])
      bdata = getdata(g[b])
      union!(free, adata)
      delete!(free, v)
      union!(free, bdata)

    elseif op == λ
      v, b = args[1:2]
      bdata = getdata(g[b])
      union!(free, bdata)
      delete!(free, v)
    end
    return free
  end
end

function TermInterface.maketerm(::Type{<:LambdaExpr}, head, children, metadata = nothing)
  head(children...)
end

EGraphs.join(from::LambdaAnalysis, to::LambdaAnalysis) = union(from,to)

function fresh_var_generator()
  idx = 0
  function generate()
    idx += 1
    Symbol("a$idx")
  end
end

freshvar = fresh_var_generator()

# The final ruleset then looks like below and correctly renames variables when needed:

λT = @theory v e c v1 v2 a b body begin
  Let(v, e, c::Any) --> c
  Let(v1, e, Variable(v1)) --> e
  Let(v1, e, Variable(v2)) => v1 == v2 ? e : Variable(v2)
  Let(v1, e, λ(v1, body)) --> λ(v1, body)
  Apply(λ(v, body), e) --> Let(v, e, body)
  Let(v, e, Apply(a, b)) --> Apply(Let(v, e, a), Let(v, e, b))
  Let(v1, e, λ(v2, body)) => if isfree(_egraph,e,v2)
    fresh = freshvar()
    λ(fresh, Let(v1, e, Let(v2, Variable(fresh), body)))
  else
    λ(v2, Let(v1, e, body))
  end
end

g = EGraph{LambdaExpr,LambdaAnalysis}(ex)
saturate!(g, λT)
@test λ(:a4, Apply(y, Variable(:a4))) == extract!(g, astsize)
