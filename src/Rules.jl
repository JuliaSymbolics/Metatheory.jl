module Rules

using TermInterface
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
  direct_right_to_left

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
  left::Pat
  right::Union{Function,Pat}
  patvars::Vector{Symbol}
  ematcher_left!::Function
  ematcher_right!::Union{Nothing,Function} = nothing
  matcher_left::Function
  matcher_right::Union{Nothing,Function} = nothing
  stack::OptBuffer{UInt16} = OptBuffer{UInt16}(STACK_SIZE)
  lhs_original = nothing
  rhs_original = nothing
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
  is_dynamic = r.op == (|>)
  print(io, r.left)
  print(io, " ")
  print(io, is_dynamic ? :(=>) : String(nameof(r.op)))
  print(io, " ")
  print(io, is_dynamic ? r.rhs_original : r.right)
  isempty(r.name) || print(io, "\t#= $(r.name) =#")
end


(r::DirectedRule)(term) = r.matcher_left(term, (bindings...) -> instantiate(term, r.right, bindings), r.stack)
(r::DynamicRule)(term) = r.matcher_left(term, (bindings...) -> r.right(term, nothing, bindings...), r.stack)

# ---------------------
# Theories


const Theory = Vector{RewriteRule}

# struct Theory
#   name::String
#   rules::Vector{RewriteRule}
# end

# ---------------------
# Instantiation

function instantiate(left, pat::Pat, bindings)
  if pat.type === PAT_EXPR
    ntail = []
    for parg in pat.children
      instantiate_arg!(ntail, left, parg, bindings)
    end
    maketerm(typeof(left), operation(pat), ntail, nothing)
  elseif pat.type === PAT_LITERAL
    pat.head
  elseif pat.type === PAT_VARIABLE || pat.type === PAT_SEGMENT
    bindings[pat.idx]
  end
end

function instantiate_arg!(acc, left, pat::Pat, bindings)
  if pat.type === PAT_SEGMENT
    append!(acc, instantiate(left, pat, bindings))
  else
    push!(acc, instantiate(left, pat, bindings))
  end
end

function instantiate(left::Expr, pat::Pat, bindings)
  if pat.type === PAT_EXPR
    ntail = []
    if iscall(pat)
      for parg in pat.children
        instantiate_arg!(ntail, left, parg, bindings)
      end
      maketerm(Expr, :call, [pat.name; ntail], nothing)
    else
      for parg in children(pat)
        instantiate_arg!(ntail, left, parg, bindings)
      end
      maketerm(Expr, pat.head, ntail, nothing)
    end
  elseif pat.type === PAT_LITERAL
    pat.head
  elseif pat.type === PAT_VARIABLE || pat.type === PAT_SEGMENT
    bindings[pat.idx]
  end
end

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
