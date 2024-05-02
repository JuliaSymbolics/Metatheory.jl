using Metatheory, Test, TermInterface

abstract type LambdaExpr end


@matchable struct IfThenElse <: LambdaExpr
  guard
  then
  otherwise
end

@matchable struct Variable <: LambdaExpr
  x::Symbol
end

@matchable struct Fix <: LambdaExpr
  variable
  expression
end

@matchable struct Let <: LambdaExpr
  variable
  value
  body
end
@matchable struct λ <: LambdaExpr
  x::Symbol
  body
end

@matchable struct Apply <: LambdaExpr
  lambda
  value
end

@matchable struct Add <: LambdaExpr
  x
  y
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

open_term = @theory x e then alt a b c begin
  # if-true 
  IfThenElse(true, then, alt) --> then
  IfThenElse(false, then, alt) --> alt
  # if-elim
  IfThenElse(Variable(x) == e, then, alt) =>
    if addexpr!(_egraph, Let(x, e, then)) == addexpr!(_egraph, Let(x, e, alt))
      alt
    else
      _lhs_expr
    end
  Add(a, b) == Add(b, a)
  Add(a, Add(b, c)) == Add(Add(a, b), c)
  # (a == b) == (b == a)
end

subst_intro = @theory v body e begin
  Fix(v, e) --> Let(v, Fix(v, e), e)
  # beta reduction 
  Apply(λ(v, body), e) --> Let(v, e, body)
end

subst_prop = @theory v e a b then alt guard begin
  # let-Apply
  Let(v, e, Apply(a, b)) --> Apply(Let(v, e, a), Let(v, e, b))
  # let-add
  Let(v, e, a + b) --> Let(v, e, a) + Let(v, e, b)
  # let-eq
  # Let(v, e, a == b) --> Let(v, e, a) == Let(v, e, b)
  # let-IfThenElse (let-if)
  Let(v, e, IfThenElse(guard, then, alt)) --> IfThenElse(Let(v, e, guard), Let(v, e, then), Let(v, e, alt))
end


isfree(eclass, id) = id ∈ getdata(eclass)

function fresh_var_generator()
  idx = 0
  function generate()
    idx += 1
    Symbol("a$idx")
  end
end

freshvar = fresh_var_generator()

subst_elim = @theory v e c v1 v2 body begin
  # let-const 
  Let(v, e, c::Any) --> c
  # let-Variable-same 
  Let(v1, e, Variable(v1)) --> e
  # TODO fancy let-Variable-diff 
  Let(v1, e, Variable(v2)) => v1 == v2 ? e : Variable(v2)
  # let-lam-same 
  Let(v1, e, λ(v1, body)) --> λ(v1, body)
  # let-lam-diff #TODO captureavoid
  Let(v1, e, λ(v2, body)) => if isfree(e,v2)
    fresh = freshvar()
    λ(fresh, Let(v1, e, Let(v2, Variable(fresh), body)))
  else
    λ(v2, Let(v1, e, body))
  end
end

λT = subst_intro ∪ subst_prop ∪ subst_elim
#λT = open_term ∪ subst_intro ∪ subst_prop ∪ subst_elim

x = Variable(:x)
y = Variable(:y)
ex = Apply(λ(:x, λ(:y, Apply(x,y))), y)
g = EGraph{LambdaExpr,LambdaAnalysis}(ex)
saturate!(g, λT)
@test λ(:a4, Apply(y, Variable(:a4))) == extract!(g, astsize)

ex = λ(:x, Add(4, Apply(λ(:y, y), 4)))
g = EGraph{LambdaExpr,LambdaAnalysis}(ex)
saturate!(g, λT)
r = extract!(g, astsize)
@test λ(:x, Add(4, 4)) == extract!(g, astsize) # expected: :(λ(x, 4 + 4))
