"""
    Patterns

Pattern types and utilities used by Metatheory's matching and rewriting
backends.
"""
module Patterns

import Metatheory: alwaystrue
import TermInterface
import TermInterface: arguments, exprhead, operation, similarterm


"""
    AbstractPat

Abstract supertype for patterns consumed by Metatheory's classical and e-graph
matchers.

Concrete patterns must expose the TermInterface tree methods when they represent
compound terms. Pattern variables and segment patterns are the two built-in
binding forms. Users normally construct them through [`@rule`](@ref) rather
than calling these constructors directly.
"""
abstract type AbstractPat end


"""
    UnsupportedPatternException(pattern)

Exception thrown when a backend cannot match `pattern`.

# Fields

- `p`: Unsupported [`AbstractPat`](@ref).
"""
struct UnsupportedPatternException <: Exception
  p::AbstractPat
end

Base.showerror(io::IO, e::UnsupportedPatternException) = print(io, "Pattern ", e.p, " is unsupported in this context")


Base.:(==)(a::AbstractPat, b::AbstractPat) = false
TermInterface.arity(p::AbstractPat) = 0
"""
    isground(pattern) -> Bool

Return `true` when `pattern` contains no [`PatVar`](@ref) or
[`PatSegment`](@ref) bindings and can therefore be looked up as a literal
term. Non-pattern values are ground by definition.
"""
isground(p::AbstractPat) = false
isground(x) = true # literals

# PatVar is equivalent to SymbolicUtils's Slot
"""
    PatVar{P}(name, debrujin_index, predicate::P)

Represent a pattern variable that matches exactly one subterm.

# Arguments

- `name::Symbol`: Name used when displaying the pattern.
- `debrujin_index::Int`: Matcher binding index; `-1` means it has not yet been
  assigned by [`setdebrujin!`](@ref).
- `predicate`: Function or type restriction applied to each candidate match.

# Fields

- `name`, `idx`, `predicate`, `predicate_code`: Mutable matcher state. The
  `idx` and `predicate_code` fields are compiler bookkeeping and should be
  left to the rule constructors.

The short constructor `PatVar(:x)` creates an unrestricted variable. In user
syntax, the equivalent pattern is `~x`; a type or predicate can be written as
`~x::Number` or `~x::is_valid`.

# Example

```julia
r = @rule sin(~x::Number) --> cos(~x)
r(:(sin(1)))
```

Matcher pattern may contain pattern variables with attached predicates,
where `predicate` is a function that takes a matched expression and returns a
boolean value. Such a slot will be considered a match only if `f` returns true.

`predicate` can also be a `Type{<:t}`, this predicate is called a 
type assertion. Type assertions on a `PatVar`, will match if and only if 
the type of the matched term for the pattern variable is a subtype of `T`. 
"""
mutable struct PatVar{P} <: AbstractPat
  name::Symbol
  idx::Int
  predicate::P
  predicate_code
end
Base.:(==)(a::PatVar, b::PatVar) = a.idx == b.idx
PatVar(var) = PatVar(var, -1, alwaystrue, nothing)
PatVar(var, i) = PatVar(var, i, alwaystrue, nothing)

"""
    PatSegment{P}(name, debrujin_index, predicate::P)

Represent a pattern variable that matches zero or more consecutive arguments.

# Arguments

- `name::Symbol`: Name used when displaying the pattern.
- `debrujin_index::Int`: Matcher binding index, assigned by
  [`setdebrujin!`](@ref).
- `predicate`: Function applied to the complete vector of matched arguments.

The short constructor `PatSegment(:xs)` creates an unrestricted segment. In
user syntax, the equivalent pattern is `~xs...`. A segment predicate receives
the vector of matched terms and must return a Boolean.

# Example

```julia
r = @rule f(~xs...) --> g(~xs...)
r(:(f(a, b)))
```
"""
mutable struct PatSegment{P} <: AbstractPat
  name::Symbol
  idx::Int
  predicate::P
  predicate_code
end

PatSegment(v) = PatSegment(v, -1, alwaystrue, nothing)
PatSegment(v, i) = PatSegment(v, i, alwaystrue, nothing)


"""
    PatTerm(exprhead, operation, args)

Represent a compound pattern with a term-interface head, operation, and child
patterns.

# Arguments

- `exprhead`: Expression head, usually `:call`.
- `operation`: Function, operator, or literal operation to match.
- `args::Vector`: Child patterns, matched in order.

A `PatTerm` matches only a term with the same expression head, operation, and
arity. It is normally produced by [`@rule`](@ref); direct construction is
useful for implementing custom matchers.
"""
struct PatTerm <: AbstractPat
  exprhead::Any
  operation::Any
  args::Vector
  PatTerm(eh, op, args) = new(eh, op, args) #Ref{UInt}(0))
end
TermInterface.istree(::PatTerm) = true
TermInterface.exprhead(e::PatTerm) = e.exprhead
TermInterface.operation(p::PatTerm) = p.operation
TermInterface.arguments(p::PatTerm) = p.args
TermInterface.arity(p::PatTerm) = length(arguments(p))
TermInterface.metadata(p::PatTerm) = nothing

function TermInterface.similarterm(x::PatTerm, head, args, symtype = nothing; metadata = nothing, exprhead = :call)
  PatTerm(exprhead, head, args)
end

isground(p::PatTerm) = all(isground, p.args)


# ==============================================
# ================== PATTERN VARIABLES =========
# ==============================================

"""
    patvars(pattern) -> Vector{Symbol}

Collect the unique pattern-variable names appearing in `pattern`, in traversal
order. Literal values do not contribute names.
"""
patvars(p::PatVar, s) = push!(s, p.name)
patvars(p::PatSegment, s) = push!(s, p.name)
patvars(p::PatTerm, s) = (patvars(operation(p), s); foreach(x -> patvars(x, s), arguments(p)); s)
patvars(x, s) = s
patvars(p) = unique!(patvars(p, Symbol[]))


# ==============================================
# ================== DEBRUJIN INDEXING =========
# ==============================================

"""
    setdebrujin!(pattern, variables)

Assign de Bruijn indices to pattern variables in `pattern`.

# Arguments

- `pattern`: Pattern to mutate.
- `variables`: Ordered collection of variable names; each pattern variable's
  index is its position in this collection.

The operation mutates `PatVar` and `PatSegment` instances and recursively visits
`PatTerm` arguments. Literal values are ignored.
"""
function setdebrujin!(p::Union{PatVar,PatSegment}, pvars)
  p.idx = findfirst((==)(p.name), pvars)
end

# literal case
setdebrujin!(p, pvars) = nothing

function setdebrujin!(p::PatTerm, pvars)
  setdebrujin!(operation(p), pvars)
  foreach(x -> setdebrujin!(x, pvars), p.args)
end


to_expr(x) = x
to_expr(x::PatVar{T}) where {T} = Expr(:call, :~, Expr(:(::), x.name, x.predicate_code))
to_expr(x::PatSegment{T}) where {T<:Function} = Expr(:..., Expr(:call, :~, Expr(:(::), x.name, x.predicate_code)))
to_expr(x::PatVar{typeof(alwaystrue)}) = Expr(:call, :~, x.name)
to_expr(x::PatSegment{typeof(alwaystrue)}) = Expr(:..., Expr(:call, :~, x.name))
to_expr(x::PatTerm) = similarterm(Expr(:call, :x), operation(x), map(to_expr, arguments(x)); exprhead = exprhead(x))

Base.show(io::IO, pat::AbstractPat) = print(io, to_expr(pat))


# include("rules/patterns.jl")
export AbstractPat
export PatVar
export PatTerm
export PatSegment
export patvars
export setdebrujin!
export isground
export UnsupportedPatternException


end
