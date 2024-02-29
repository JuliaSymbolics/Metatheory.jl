using Metatheory, Test

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


function TermInterface.maketerm(::Type{LambdaExpr}, head, children; is_call = true, type = Any, metadata = nothing)
  head(children...)
end

function EGraphs.make(::Val{:freevar}, g::EGraph, n::VecExpr)
  free = Set{Int64}()
  v_isexpr(n) || return free
  if v_iscall(n)
    op = get_constant(g, v_head(n))
    args = v_children(n)

    if op == Variable
      push!(free, args[1])
    elseif op == Let
      v, a, b = args[1:3]
      adata = getdata(g[a], :freevar, Set{Int64}())
      bdata = getdata(g[a], :freevar, Set{Int64}())
      union!(free, adata)
      delete!(free, v)
      union!(free, bdata)
    elseif op == λ
      v, b = args[1:2]
      bdata = getdata(g[b], :freevar, Set{Int64}())
      union!(free, bdata)
      delete!(free, v)
    end
  end

  return free
end

EGraphs.join(::Val{:freevar}, from, to) = union(from, to)

islazy(::Val{:freevar}) = false

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


subst_elim = @theory v e c v1 v2 body begin
  # let-const 
  Let(v, e, c::Any) --> c
  # let-Variable-same 
  Let(v1, e, Variable(v1)) --> e
  # TODO fancy let-Variable-diff 
  Let(v1, e, Variable(v2)) => if addexpr!(_egraph, v1) != addexpr!(_egraph, v2)
    :(Variable($v2))
  else
    _lhs_expr
  end
  # let-lam-same 
  Let(v1, e, λ(v1, body)) --> λ(v1, body)
  # let-lam-diff #TODO captureavoid
  Let(v1, e, λ(v2, body)) => if v2.id ∈ getdata(e, :freevar, Set()) # is free
    :(λ($fresh, Let($v1, $e, Let($v2, Variable($fresh), $body))))
  else
    :(λ($v2, Let($v1, $e, $body)))
  end
end

λT = open_term ∪ subst_intro ∪ subst_prop ∪ subst_elim

ex = λ(:x, Add(4, Apply(λ(:y, Variable(:y)), 4)))
g = EGraph{LambdaExpr}(ex)

saturate!(g, λT)
@test λ(:x, Add(4, 4)) == extract!(g, astsize) # expected: :(λ(x, 4 + 4))

#%%
g = EGraph{LambdaExpr}()
@test areequal(g, λT, 2, Apply(λ(:x, Variable(:x)), 2))