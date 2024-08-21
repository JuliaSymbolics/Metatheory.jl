module Rules

using Base.Threads
using TermInterface
using AutoHashEquals
using Metatheory.Patterns
using Metatheory.Patterns: to_expr
using Metatheory: OptBuffer

export RewriteRule,
  DirectedRule,
  EqualityRule,
  UnequalRule,
  DynamicRule,
  -->,
  is_bidirectional,
  Theory,
  direct,
  direct_left_to_right,
  direct_right_to_left,
  get_local_stack

const STACK_SIZE = 512

"""
Rules in Metatheory can be defined with the `@rule` macro.

Rules defined as with the --> are
called *directed rewrite* rules. Application of a *directed rewrite* rule
is a replacement of the `left` pattern with
the `right` substitution, with the correct instantiation
of pattern variables.

```julia
@rule ~a * ~b --> ~b * ~a
```

An *equational rule* is a symbolic substitution rule with operator `==` that
can be rewritten bidirectionally. Therefore, it can only be used
with the EGraphs backend.

```julia
@rule ~a * ~b == ~b * ~a
```

Rules defined with the `!=` act as  *anti*-rules for checking contradictions in e-graph
rewriting. If two terms, corresponding to the left and right hand side of an
*anti-rule* are found in an `EGraph`, saturation is halted immediately.

```julia
!a != a
````

Rules defined with the `=>` operator are
called *dynamic rules*. Dynamic rules behave like anonymous functions.
Instead of a symbolic substitution, the right hand of
a dynamic `=>` rule is evaluated during rewriting:
matched values are bound to pattern variables as in a
regular function call. This allows for dynamic computation
of right hand sides.

```julia
@rule ~a::Number * ~b::Number => ~a*~b
```
"""
Base.@kwdef struct RewriteRule{Op<:Function}
  name::String = ""
  op::Op
  left::AbstractPat
  right::Union{Function,AbstractPat}
  patvars::Vector{Symbol}
  ematcher_left!::Function
  ematcher_right!::Union{Nothing,Function} = nothing
  matcher_left::Function
  matcher_right::Union{Nothing,Function} = nothing
  lhs_original = nothing
  rhs_original = nothing
end

const THREAD_STACKS = OptBuffer{UInt16}[]
"""
Retrieve the per-thread stack thread used for program counters in matching.

We need a stack for each thread so that multithreading works correctly.

Modeled off [Julia's global RNG](https://github.com/JuliaLang/julia/blob/bc4b2e848400764e389c825b57d1481ed76f4d85/stdlib/Random/src/RNGs.jl)
"""
@inline get_local_stack() = get_local_stack(Threads.threadid())
@noinline function get_local_stack(tid::Int)
  @assert 0 < tid <= length(THREAD_STACKS)
  if @inbounds isassigned(THREAD_STACKS, tid)
    @inbounds stack = THREAD_STACKS[tid]
  else
    stack = OptBuffer{UInt16}(STACK_SIZE)
    @inbounds THREAD_STACKS[tid] = stack
  end
  return stack
end

function __init__()
  resize!(empty!(THREAD_STACKS), Threads.nthreads())
end

function --> end
const DirectedRule = RewriteRule{typeof(-->)}
const EqualityRule = RewriteRule{typeof(==)}
const UnequalRule = RewriteRule{typeof(!=)}
# FIXME => is not a function we have to use |>
const DynamicRule = RewriteRule{typeof(|>)}


is_bidirectional(r::RewriteRule) = r.op in (==, !=)

# TODO equivalence up-to debruijn index
Base.:(==)(a::RewriteRule, b::RewriteRule) = a.op == b.op && a.left == b.left && a.right == b.right

function Base.show(io::IO, r::RewriteRule)
  print(io, r.left)
  print(io, " ")
  print(io, r.op == (|>) ? :(=>) : String(nameof(r.op)))
  print(io, " ")
  print(io, r.rhs_original)
  isempty(r.name) || print(io, "\t#= $(r.name) =#")
end


(r::DirectedRule)(term) = r.matcher_left(term, (bindings...) -> instantiate(term, r.right, bindings), get_local_stack())
(r::DynamicRule)(term) = r.matcher_left(term, (bindings...) -> r.right(term, nothing, bindings...), get_local_stack())

# ---------------------
# Theories


const Theory = Vector{RewriteRule}

# struct Theory
#   name::String
#   rules::Vector{RewriteRule}
# end

# ---------------------
# Instantiation

function instantiate(left, pat::PatExpr, bindings)
  ntail = []
  for parg in arguments(pat)
    instantiate_arg!(ntail, left, parg, bindings)
  end
  maketerm(typeof(left), operation(pat), ntail, nothing)
end

function instantiate(left::Expr, pat::PatExpr, bindings)
  ntail = []
  if iscall(pat)
    for parg in arguments(pat)
      instantiate_arg!(ntail, left, parg, bindings)
    end
    op = operation(pat)
    op_name = op isa Union{Function,DataType} ? nameof(op) : op
    maketerm(Expr, :call, [op_name; ntail], nothing)
  else
    for parg in children(pat)
      instantiate_arg!(ntail, left, parg, bindings)
    end
    maketerm(Expr, head(pat), ntail, nothing)
  end
end

instantiate_arg!(acc, left, parg::PatSegment, bindings) = append!(acc, instantiate(left, parg, bindings))
instantiate_arg!(acc, left, parg::AbstractPat, bindings) = push!(acc, instantiate(left, parg, bindings))

instantiate(_, pat::PatLiteral, bindings) = pat.value
instantiate(_, pat::Union{PatVar,PatSegment}, bindings) = bindings[pat.idx]

"Inverts the direction of a rewrite rule, swapping the LHS and the RHS"
function Base.inv(r::RewriteRule)
  RewriteRule(
    name = r.name,
    op = r.op,
    left = r.right,
    right = r.left,
    patvars = r.patvars,
    ematcher_left! = r.ematcher_right!,
    ematcher_right! = r.ematcher_left!,
    matcher_left = r.matcher_right,
    matcher_right = r.matcher_left,
    lhs_original = r.rhs_original,
    rhs_original = r.lhs_original,
  )
end

"""
Turns an EqualityRule into a DirectedRule. For example,

```julia
direct(@rule f(~x) == g(~x)) == f(~x) --> g(~x)
```
"""
function direct(r::EqualityRule)
  RewriteRule(r.name, -->, (getfield(r, k) for k in fieldnames(DirectedRule)[3:end])...)
end

"""
Turns an EqualityRule into a DirectedRule, but right to left. For example,

```julia
direct(@rule f(~x) == g(~x)) == g(~x) --> f(~x)
```
"""
direct_right_to_left(r::EqualityRule) = inv(direct(r))
direct_left_to_right(r::EqualityRule) = direct(r)

end
