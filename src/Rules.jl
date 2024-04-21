module Rules

using TermInterface
using AutoHashEquals
using Metatheory.EMatchCompiler
using Metatheory.Patterns
using Metatheory.Patterns: to_expr
using Metatheory: cleanast, matcher, instantiate

const EMPTY_DICT = Base.ImmutableDict{Int,Any}()

abstract type AbstractRule end
# Must override
Base.:(==)(a::AbstractRule, b::AbstractRule) = false

abstract type SymbolicRule <: AbstractRule end

abstract type BidirRule <: SymbolicRule end

struct RuleRewriteError
  rule
  expr
  err
end


@noinline function Base.showerror(io::IO, err::RuleRewriteError)
  print(io, "Failed to apply rule $(err.rule) on expression ")
  print(io, Base.show(IOContext(io, :simplify => false), err.expr))
  Base.showerror(io, err.err)
end


"""
Rules defined as `left_hand --> right_hand` are
called *symbolic rewrite* rules. Application of a *rewrite* Rule
is a replacement of the `left_hand` pattern with
the `right_hand` substitution, with the correct instantiation
of pattern variables. Function call symbols are not treated as pattern
variables, all other identifiers are treated as pattern variables.
Literals such as `5, :e, "hello"` are not treated as pattern
variables.


```julia
@rule ~a * ~b --> ~b * ~a
```
"""
@auto_hash_equals fields = (left, right) struct RewriteRule <: SymbolicRule
  left
  right
  matcher
  patvars::Vector{Symbol}
  ematcher!
  ematcher_new!
end

function RewriteRule(l, r)
  pvars = patvars(l) ∪ patvars(r)
  # sort!(pvars)
  setdebrujin!(l, pvars)
  setdebrujin!(r, pvars)
  RewriteRule(l, r, matcher(l), pvars, ematcher_yield(l, length(pvars)), nothing)
end

function RewriteRule(l, r, ematcher_new!)
  pvars = patvars(l) ∪ patvars(r)
  # sort!(pvars)
  setdebrujin!(l, pvars)
  setdebrujin!(r, pvars)
  RewriteRule(l, r, matcher(l), pvars, ematcher_yield(l, length(pvars)), ematcher_new!)
end

Base.show(io::IO, r::RewriteRule) = print(io, :($(r.left) --> $(r.right)))


function (r::RewriteRule)(term)
  # n == 1 means that exactly one term of the input (term,) was matched
  success(bindings, n) = n == 1 ? instantiate(term, r.right, bindings) : nothing

  try
    r.matcher(success, (term,), EMPTY_DICT)
  catch err
    rethrow(err)
    throw(RuleRewriteError(r, term, err))
  end
end

# ============================================================
# EqualityRule
# ============================================================

"""
An `EqualityRule` can is a symbolic substitution rule that 
can be rewritten bidirectional. Therefore, it should only be used 
with the EGraphs backend.

```julia
@rule ~a * ~b == ~b * ~a
```
"""
@auto_hash_equals struct EqualityRule <: BidirRule
  left
  right
  patvars::Vector{Symbol}
  ematcher!
end

function EqualityRule(l, r)
  pvars = patvars(l) ∪ patvars(r)
  extravars = setdiff(pvars, patvars(l) ∩ patvars(r))
  if !isempty(extravars)
    error("unbound pattern variables $extravars when creating bidirectional rule")
  end
  setdebrujin!(l, pvars)
  setdebrujin!(r, pvars)

  EqualityRule(l, r, pvars, ematcher_yield_bidir(l, r, length(pvars)))
end


Base.show(io::IO, r::EqualityRule) = print(io, :($(r.left) == $(r.right)))

# ============================================================
# UnequalRule
# ============================================================

"""
This type of *anti*-rules is used for checking contradictions in the EGraph
backend. If two terms, corresponding to the left and right hand side of an
*anti-rule* are found in an [`EGraph`], saturation is halted immediately. 

```julia
!a ≠ a
```

"""
@auto_hash_equals struct UnequalRule <: BidirRule
  left
  right
  patvars::Vector{Symbol}
  ematcher!
end

function UnequalRule(l, r)
  pvars = patvars(l) ∪ patvars(r)
  extravars = setdiff(pvars, patvars(l) ∩ patvars(r))
  if !isempty(extravars)
    error("unbound pattern variables $extravars when creating bidirectional rule")
  end
  # sort!(pvars)
  setdebrujin!(l, pvars)
  setdebrujin!(r, pvars)
  UnequalRule(l, r, pvars, ematcher_yield_bidir(l, r, length(pvars)))
end

Base.show(io::IO, r::UnequalRule) = print(io, :($(r.left) ≠ $(r.right)))

# ============================================================
# DynamicRule
# ============================================================
"""
Rules defined as `left_hand => right_hand` are
called `dynamic` rules. Dynamic rules behave like anonymous functions.
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
@auto_hash_equals struct DynamicRule <: AbstractRule
  left
  rhs_fun::Function
  rhs_code
  matcher
  patvars::Vector{Symbol} # useful set of pattern variables
  ematcher!
  ematcher_new!
end

function DynamicRule(l, r::Function, ematcher_new!, rhs_code = nothing)
  pvars = patvars(l)
  setdebrujin!(l, pvars)
  isnothing(rhs_code) && (rhs_code = repr(rhs_code))

  DynamicRule(l, r, rhs_code, matcher(l), pvars, ematcher_yield(l, length(pvars)), ematcher_new!)
end


Base.show(io::IO, r::DynamicRule) = print(io, :($(r.left) => $(r.rhs_code)))

function (r::DynamicRule)(term)
  # n == 1 means that exactly one term of the input (term,) was matched
  success(bindings, n) =
    if n == 1
      bvals = [bindings[i] for i in 1:length(r.patvars)]
      return r.rhs_fun(term, nothing, bvals...)
    end

  try
    return r.matcher(success, (term,), EMPTY_DICT)
  catch err
    throw(RuleRewriteError(r, term, err))
  end
end

export SymbolicRule
export RewriteRule
export BidirRule
export EqualityRule
export UnequalRule
export DynamicRule
export AbstractRule

end
