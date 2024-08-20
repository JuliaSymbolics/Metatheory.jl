using Metatheory, Test, TermInterface

# # Lambda theory
#
# This tutorial demonstrates how to implement a simple lambda calculus in Metatheory.
# Importantly, it shows a practical example of [*e-graph analysis*](/egraphs/#EGraph-Analyses).
# The three building blocks of lambda calculus are *variables*, $\lambda$-functions, and *function
# application*, which we can implement as subtypes of an abstract `LambdaExpr`ession:

abstract type LambdaExpr end

function TermInterface.maketerm(::Type{<:LambdaExpr}, head, children, metadata = nothing)
  head(children...)
end

@matchable struct Variable <: LambdaExpr
  x
end
Base.show(io::IO, x::Variable) = print(io, "$(x.x)")

@matchable struct λ <: LambdaExpr
  x
  body
end
function Base.show(io::IO, x::λ)
  b = x.body isa Variable ? "$(x.body)" : "($(x.body))"
  print(io, "λ$(x.x).$b")
end

@matchable struct Apply <: LambdaExpr
  lambda
  value
end
function Base.show(io::IO, x::Apply)
  l = x.lambda isa Variable ? "$(x.lambda)" : "($(x.lambda))"
  v = x.value isa Variable ? "$(x.value)" : "($(x.value))"
  print(io, "$l$v")
end

# With the above we can construct arbitrary lambda expressions:

x = Variable(:x)
λ(:x, Apply(x, x))

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
  Let(v1, e, λ(v2, body)) --> λ(v2, Let(v1, e, body)) # let-lam-diff
  Apply(λ(v, body), e) --> Let(v, e, body) # beta reduction
  Let(v, e, Apply(a, b)) --> Apply(Let(v, e, a), Let(v, e, b)) # let-Apply
end

x = Variable(:x)
y = Variable(:y)
ex = Apply(λ(:x, λ(:y, Apply(x, y))), y)
g = EGraph(ex)
saturate!(g, λT)
extract!(g, astsize)


# Unfortunately, the above does not correctly perform $\alpha$-conversion. To do
# so we need to keep track of free and bound variables in each eclass.
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
# > Recently, a much better way to represent languages with bound variables with
# > [*slotted E-Graphs*](https://pldi24.sigplan.org/details/egraphs-2024-papers/10/Slotted-E-Graphs)
# > has been proposed. They make bound variables a built in feature of the e-graph.
#
# In the more basic implementation here we just want to be able to check if a variable is free:

function isfree(g::EGraph, eclass, var)
  @assert length(var.nodes) == 1
  var_sym = get_constant(g, v_head(var.nodes[1]))
  @assert var_sym isa Symbol
  var_sym ∈ getdata(eclass)
end

# This can be done via a `LambdaAnalysis` datastructure which we can include in an
# `EClass`. We overload Egraphs.make such that whenever we add a new enode to
# the egraph we keep track of the free variables.

const LambdaAnalysis = Set{Symbol}

getdata(eclass) = eclass.data

function EGraphs.make(g::EGraph{ExprType,LambdaAnalysis}, n::VecExpr) where {ExprType}
  v_isexpr(n) || return LambdaAnalysis()
  if v_iscall(n)
    h = v_head(n)
    op = get_constant(g, h)
    args = v_children(n)
    eclass = g[args[1]]
    free = copy(getdata(eclass))

    if op == Variable
      push!(free, get_constant(g, v_head(eclass.nodes[1])))
    elseif op == Let
      v, a, b = args[1:3] # v=a in b
      vclass = g[v]
      vsy = get_constant(g, v_head(vclass.nodes[1]))
      adata = getdata(g[a])
      bdata = getdata(g[b])
      union!(free, bdata)
      delete!(free, vsy)
      union!(free, adata)
    elseif op == λ
      v, b = args[1:2]
      vclass = g[v]
      vsy = get_constant(g, v_head(vclass.nodes[1]))
      bdata = getdata(g[b])
      union!(free, bdata)
      delete!(free, vsy)
    elseif op == Apply
      l, v = args[1:2]
      ldata = getdata(g[l])
      vdata = getdata(g[v])
      union!(free, ldata)
      union!(free, vdata)
    end
    return free
  end
end

function EGraphs.join(from::LambdaAnalysis, to::LambdaAnalysis)
  if issubset(from, to) # includes case from==to
    from
  elseif issubset(to, from)
    to
  else
    error("inconsistent free variable sets from: $from to: $to")
  end
end

function fresh_var_generator()
  idx = 0
  function generate()
    idx += 1
    chars = collect(string(idx))
    subs = map(digit -> Char(Int(digit) + Int('₀') - Int('0')), chars)
    Symbol("a$(String(subs))")
  end
end

freshvar = fresh_var_generator()

# The final ruleset then looks like below and correctly renames variables when needed:

λT = @theory v e c v1 v2 a b body begin
  # let(v,e,body) means let v = e in body
  Let(v, e, c::Any) --> c
  Let(v1, e, Variable(v1)) --> e
  Let(v1, e, Variable(v2)) => v1 == v2 ? e : Variable(v2)
  Let(v1, e, λ(v1, body)) --> λ(v1, body)
  Apply(λ(v, body), e) --> Let(v, e, body)
  Let(v, e, Apply(a, b)) --> Apply(Let(v, e, a), Let(v, e, b))
  Let(v1, e, λ(v2, body)) => if isfree(_egraph, e, v2)
    fresh = freshvar()
    λ(fresh, Let(v1, e, Let(v2, Variable(fresh), body)))
  else
    λ(v2, Let(v1, e, body))
  end
end

x = Variable(:x)
y = Variable(:y)
ex = Apply(λ(:x, λ(:y, Apply(x, y))), y)
g = EGraph{LambdaExpr,LambdaAnalysis}(ex)
params = SaturationParams(
  timer = false,
  check_analysis = true
)
saturate!(g, λT, params)
@test λ(:a₄, Apply(y, Variable(:a₄))) == extract!(g, astsize)
@test Set([:y]) == g[g.root].data


# With the above we can implement, for example, Church numerals.

s = Variable(:s)
z = Variable(:z)
n = Variable(:n)
zero = λ(:s, λ(:z, z))
one = λ(:s, λ(:z, Apply(s, z)))
two = λ(:s, λ(:z, Apply(s, Apply(s, z))))
suc = λ(:n, λ(:x, λ(:y, Apply(x, Apply(Apply(n, x), y)))))

# Compute the successor of `one`:

freshvar = fresh_var_generator()
g = EGraph{LambdaExpr,LambdaAnalysis}(Apply(suc, one))
params = SaturationParams(
  timeout = 20,
  scheduler = Schedulers.BackoffScheduler,
  schedulerparams = (match_limit = 6000, ban_length = 5),
  timer = false,
  check_analysis = true
)
saturate!(g, λT, params)
two_ = extract!(g, astsize)
@test two_ == λ(:x, λ(:y, Apply(Variable(:x), Apply(Variable(:x), Variable(:y)))))
@test g[g.root].data == Set([])
two_

# which is the same as `two` up to $\alpha$-conversion:

two

# check semantic analysis for free variables
function test_free_variable_analysis(expr, free)
  g = EGraph{LambdaExpr,LambdaAnalysis}(expr)
  g[g.root].data == free
end

@test test_free_variable_analysis(Variable(:x), Set([:x]))
@test test_free_variable_analysis(Apply(Variable(:x), Variable(:y)), Set([:x, :y]))
@test test_free_variable_analysis(λ(:z, Variable(:x)), Set([:x]))
@test test_free_variable_analysis(λ(:z, Variable(:z)), Set{Symbol}())
@test test_free_variable_analysis(λ(:z, λ(:x, Variable(:x))), Set{Symbol}())

let_expr = Let(:x, Variable(:z), λ(:x, Variable(:y)))
@test test_free_variable_analysis(let_expr, Set([:z, :y]))
# after saturation the expression becomes λ(:x, Variable(:y)) where only :y is left as free variable
freshvar = fresh_var_generator()
g = EGraph{LambdaExpr,LambdaAnalysis}(let_expr)
saturate!(g, λT, params)
@test extract!(g, astsize) == λ(:x, Variable(:y))
@test g[g.root].data == Set([:y])