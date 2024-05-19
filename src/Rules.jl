module Rules

using TermInterface
using AutoHashEquals
using Metatheory.Patterns
using Metatheory.Patterns: to_expr
using Metatheory: cleanast, matcher, instantiate
using Metatheory: OptBuffer

export RewriteRule, DirectedRule, EqualityRule, UnequalRule, DynamicRule, -->, is_bidirectional

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

An `EqualityRule` is a symbolic substitution rule with operator `==` that 
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
called dynamic rules. Dynamic rules behave like anonymous functions.
Instead of a symbolic substitution, the right hand of
a dynamic `=>` rule is evaluated during rewriting:
matched values are bound to pattern variables as in a
regular function call. This allows for dynamic computation
of right hand sides.

Dynamic rule
```julia
@rule ~a::Number * ~b::Number => ~a*~b
```
"""
Base.@kwdef struct RewriteRule{Op<:Union{Function}}
  op::Op
  left::AbstractPat
  right::Union{Function,AbstractPat}
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

# TODO equivalence up-to debrujin index
Base.:(==)(a::RewriteRule, b::RewriteRule) = a.op == b.op && a.left == b.left && a.right == b.right

Base.show(io::IO, r::RewriteRule) = print(io, :($(nameof(r.op))($(r.left), $(r.right))))
Base.show(io::IO, r::DynamicRule) = print(io, :($(r.left) => $(r.rhs_original)))


(r::DirectedRule)(term)::Union{Nothing,Some} =
  r.matcher_left(term, (bindings...) -> instantiate(term, r.right, bindings), r.stack)
(r::DynamicRule)(term)::Union{Nothing,Some} =
  r.matcher_left(term, (bindings...) -> r.right(term, nothing, bindings...), r.stack)



end
