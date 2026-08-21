"""
    Rules

Rule types used by Metatheory's pattern matcher and equality-saturation
engine. Rules are callable and return a rewritten value or `nothing`.
"""
module Rules

import AutoHashEquals: @auto_hash_equals
import Metatheory.EMatchCompiler: ematcher_yield, ematcher_yield_bidir
import Metatheory.Patterns: patvars, setdebrujin!
import Metatheory: instantiate, matcher

const EMPTY_DICT = Base.ImmutableDict{Int,Any}()

"""
    AbstractRule

Abstract supertype for all Metatheory rules.

Concrete subtypes must be callable on a term. A rule returns the rewritten term
when it matches and `nothing` otherwise. E-graph saturation additionally
expects the rule to expose the pattern information required by its matcher.

# Interface contract

Implement `(::MyRule)(term)`, return `nothing` for a non-match, and define
equality if rules are stored in dictionaries or scheduler state. Subtype
[`SymbolicRule`](@ref Metatheory.Rules.SymbolicRule) when the rule has symbolic left and right patterns.

# Example

```julia
struct IdentityRule <: AbstractRule end
(::IdentityRule)(term) = term === :x ? :y : nothing
```
"""
abstract type AbstractRule end
# Must override
Base.:(==)(a::AbstractRule, b::AbstractRule) = false

"""
    SymbolicRule <: AbstractRule

Abstract supertype for rules whose left and right sides are symbolic patterns.
Subtypes store pattern data and are normally constructed by [`@rule`](@ref Metatheory.Syntax.@rule).
"""
abstract type SymbolicRule <: AbstractRule end

"""
    BidirRule <: SymbolicRule

Abstract supertype for rules that may be matched in either direction by an
e-graph. Both sides must bind the same variables so either direction is valid.
"""
abstract type BidirRule <: SymbolicRule end

struct RuleRewriteError
  rule
  expr
end

getdepth(::Any) = typemax(Int)

showraw(io, t) = Base.show(IOContext(io, :simplify => false), t)
showraw(t) = showraw(stdout, t)

@noinline function Base.showerror(io::IO, err::RuleRewriteError)
  msg = "Failed to apply rule $(err.rule) on expression "
  msg *= sprint(io -> showraw(io, err.expr))
  print(io, msg)
end


"""
    RewriteRule(left, right)

Represent a one-way symbolic substitution rule. Applying the rule replaces the
matched `left` pattern with `right`, instantiating bound variables. Function
call symbols and literals are treated as operations/literals; identifiers in
pattern positions become variables.

# Fields

- `left`, `right`: Pattern trees.
- `matcher`, `patvars`, `ematcher!`: Compiled matcher state. These fields are
  implementation details and should not be mutated after construction.

# Example


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
end

function RewriteRule(l, r)
  pvars = patvars(l) ∪ patvars(r)
  # sort!(pvars)
  setdebrujin!(l, pvars)
  setdebrujin!(r, pvars)
  RewriteRule(l, r, matcher(l), pvars, ematcher_yield(l, length(pvars)))
end

Base.show(io::IO, r::RewriteRule) = print(io, :($(r.left) --> $(r.right)))


function (r::RewriteRule)(term)
  # n == 1 means that exactly one term of the input (term,) was matched
  success(bindings, n) = n == 1 ? instantiate(term, r.right, bindings) : nothing

  try
    r.matcher(success, (term,), EMPTY_DICT)
  catch err
    throw(RuleRewriteError(r, term))
  end
end

# ============================================================
# EqualityRule
# ============================================================

"""
    EqualityRule(left, right)

Represent a bidirectional symbolic equality. It is intended for the EGraphs
backend, where both orientations are searched; it is not a classical rewriter.

# Fields

- `left`, `right`: Patterns that must bind the same variable names.
- `patvars`, `ematcher!`: Compiled bidirectional matcher state.

Creating a rule with a variable present on only one side throws an error.

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

function (r::EqualityRule)(x)
  throw(RuleRewriteError(r, x))
end


# ============================================================
# UnequalRule
# ============================================================

"""
    UnequalRule(left, right)

Represent an anti-rule for detecting a contradiction in an EGraph. If both
patterns are found in one equivalence class, saturation stops immediately.

# Fields

- `left`, `right`: Patterns that must bind the same variable names.
- `patvars`, `ematcher!`: Compiled matcher state.

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
    DynamicRule(left, rhs_fun[, rhs_code])

Represent a rule whose right-hand side is evaluated for each match. The
function receives the input term, an analysis context (currently `nothing` for
classical rewriting), and one positional value per pattern variable.

# Fields

- `left`: Pattern to match.
- `rhs_fun`: Callable right-hand-side implementation.
- `rhs_code`, `matcher`, `patvars`, `ematcher!`: Display and compiled matcher
  state.

Use the [`@rule`](@ref Metatheory.Syntax.@rule) `=>` form unless constructing a custom rule backend.

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
end

function DynamicRule(l, r::Function, rhs_code = nothing)
  pvars = patvars(l)
  setdebrujin!(l, pvars)
  isnothing(rhs_code) && (rhs_code = repr(rhs_code))

  DynamicRule(l, r, rhs_code, matcher(l), pvars, ematcher_yield(l, length(pvars)))
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
    rethrow(err)
    throw(RuleRewriteError(r, term))
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
