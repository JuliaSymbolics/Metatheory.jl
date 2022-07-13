#%%
using Metatheory
using Metatheory.EGraphs
using Metatheory.Library
using TermInterface
using Test

#%%
EGraphs.make(::Val{:freevar}, ::EGraph, n::ENodeLiteral) = Set{Int64}()

function EGraphs.make(::Val{:freevar}, g::EGraph, n::ENodeTerm)
  free = Set{Int64}()
  if exprhead(n) == :call
    op = operation(n)
    args = arguments(n)

    if op == :var
      push!(free, args[1])
    elseif op == :llet
      v, a, b = args[1:3]
      adata = getdata(g[a], :freevar, Set{Int64}())
      bdata = getdata(g[a], :freevar, Set{Int64}())
      union!(free, adata)
      delete!(free, v)
      union!(free, bdata)
    elseif op == :λ
      v, b = args[1:2]
      bdata = getdata(g[b], :freevar, Set{Int64}())
      union!(free, bdata)
      delete!(free, v)
    end
  end

  return free
end

function EGraphs.join(::Val{:freevar}, from, to)
  union(from, to)
end

islazy(::Val{:freevar}) = false

#%%
open_term = @theory x e then alt a b c begin
  # if-true 
  cond(true, then, alt) --> then
  cond(false, then, alt) --> alt
  # if-elim
  cond(var(x) == e, then, alt) =>
    if addexpr!(_egraph, :(llet($x, $e, $then))) == addexpr!(_egraph, :(llet($x, $e, $alt)))
      alt
    else
      _lhs_expr
    end
  a + b == b + a
  a + (b + c) == (a + b) + c
  (a == b) == (b == a)
end

#%%
subst_intro = @theory v body e begin
  fix(v, e) --> llet(v, fix(v, e), e)
  # beta reduction 
  app(λ(v, body), e) --> llet(v, e, body)
end

#%%
subst_prop = @theory v e a b then alt guard begin
  # let-app
  llet(v, e, app(a, b)) --> app(llet(v, e, a), llet(v, e, b))
  # let-add
  llet(v, e, a + b) --> llet(v, e, a) + llet(v, e, b)
  # let-eq
  llet(v, e, a == b) --> llet(v, e, a) == llet(v, e, b)
  # let-cond (let-if)
  llet(v, e, cond(guard, then, alt)) --> cond(llet(v, e, guard), llet(v, e, then), llet(v, e, alt))
end

#%%
subst_elim = @theory v e c v1 v2 body begin
  # let-const 
  llet(v, e, c::Any) --> c
  # let-var-same 
  llet(v1, e, var(v1)) --> e
  # TODO fancy let-var-diff 
  llet(v1, e, var(v2)) => if find(_egraph, v1) != find(_egraph, v2)
    :(var($v2))
  else
    _lhs_expr
  end
  # let-lam-same 
  llet(v1, e, λ(v1, body)) --> λ(v1, body)
  # let-lam-diff #TODO captureavoid
  llet(v1, e, λ(v2, body)) => if v2.id ∈ getdata(e, :freevar, Set()) # is free
    :(λ($fresh, llet($v1, $e, llet($v2, var($fresh), $body))))
  else
    :(λ($v2, llet($v1, $e, $body)))
  end
end

#%%
λT = open_term ∪ subst_intro ∪ subst_prop ∪ subst_elim

#%%
ex = :(λ(x, 4 + app(λ(y, var(y)), 4)))
g = EGraph(ex)

# analyze!(g, :freevar)
# analysis = getdata(g[g.root], :freevar)

#%%
saturate!(g, λT)
extract!(g, astsize) # expected: :(λ(x, 4 + 4))

#%%
@test @areequal λT 2 app(λ(x, var(x)), 2)
