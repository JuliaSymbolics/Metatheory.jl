# # Lambda theory
# hello
using Metatheory, Test, TermInterface

abstract type LambdaExpr end

@matchable struct Variable <: LambdaExpr
  x
end

@matchable struct Let <: LambdaExpr
  variable
  value
  body
end
@matchable struct λ <: LambdaExpr
  x
  body
end

@matchable struct Apply <: LambdaExpr
  lambda
  value
end

const LambdaAnalysis = Set{Symbol}

function TermInterface.maketerm(::Type{<:LambdaExpr}, head, children; type = nothing, metadata = nothing)
  head(children...)
end

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

EGraphs.join(from::LambdaAnalysis, to::LambdaAnalysis) = union(from,to)


function isfree(g, eclass, var)
  @assert length(var.nodes)==1
  var_sym = get_constant(g, v_head(var.nodes[1]))
  @assert var_sym isa Symbol
  var_sym ∈ getdata(eclass)
end

function fresh_var_generator()
  idx = 0
  function generate()
    idx += 1
    Symbol("a$idx")
  end
end

freshvar = fresh_var_generator()

λT = @theory v e c v1 v2 a b body begin
  # let-const 
  Let(v, e, c::Any) --> c
  # let-Variable-same 
  Let(v1, e, Variable(v1)) --> e
  # let-Variable-diff 
  Let(v1, e, Variable(v2)) => v1 == v2 ? e : Variable(v2)
  # let-lam-same 
  Let(v1, e, λ(v1, body)) --> λ(v1, body)
  # let-lam-diff
  Let(v1, e, λ(v2, body)) => if isfree(_egraph,e,v2)
    fresh = freshvar()
    λ(fresh, Let(v1, e, Let(v2, Variable(fresh), body)))
  else
    λ(v2, Let(v1, e, body))
  end
  # beta reduction 
  Apply(λ(v, body), e) --> Let(v, e, body)
  # let-Apply
  Let(v, e, Apply(a, b)) --> Apply(Let(v, e, a), Let(v, e, b))
end

x = Variable(:x)
y = Variable(:y)
ex = Apply(λ(:x, λ(:y, Apply(x,y))), y)
g = EGraph{LambdaExpr,LambdaAnalysis}(ex)
saturate!(g, λT)
@test λ(:a4, Apply(y, Variable(:a4))) == extract!(g, astsize)
