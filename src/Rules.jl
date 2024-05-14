module Rules

using TermInterface
using AutoHashEquals
using Metatheory.Patterns
using Metatheory.Patterns: to_expr
using Metatheory: cleanast, matcher, instantiate
using Metatheory: OptBuffer

export NewRewriteRule, DirectedRule, EqualityRule, UnequalRule, DynamicRule, -->, is_bidirectional

const STACK_SIZE = 512

Base.@kwdef struct NewRewriteRule{Op<:Union{Function}}
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
const DirectedRule = NewRewriteRule{typeof(-->)}
const EqualityRule = NewRewriteRule{typeof(==)}
const UnequalRule = NewRewriteRule{typeof(!=)}
# FIXME => is not a function we have to use |>
const DynamicRule = NewRewriteRule{typeof(|>)}


is_bidirectional(r::NewRewriteRule) = r.op in (==, !=)

# TODO equivalence up-to debrujin index
Base.:(==)(a::NewRewriteRule, b::NewRewriteRule) = a.op == b.op && a.left == b.left && a.right == b.right

Base.show(io::IO, r::NewRewriteRule) = print(io, :($(nameof(r.op))($(r.left), $(r.right))))
Base.show(io::IO, r::DynamicRule) = print(io, :($(r.left) => $(r.rhs_original)))


(r::DirectedRule)(term) = r.matcher_left(term, (bindings...) -> instantiate(term, r.right, bindings), r.stack)
(r::DynamicRule)(term) = r.matcher_left(term, (bindings...) -> r.right(term, nothing, bindings...), r.stack)



end
