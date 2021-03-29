"""
Abstract type representing a pattern used in all the various pattern matching backends. 
You can use the `Pattern` constructor to recursively convert an `Expr` (or any type satisfying [`Metatheory.TermInterface`](@ref)) to a [`Pattern`](@ref).
"""
abstract type Pattern end

# TODO implement debrujin indexing?
"""
Pattern variables will first match on any subterm
and instantiate the substitution to that subterm. 
"""
struct PatVar <: Pattern
    var::Symbol
end

"""
A pattern literal will match only against an instance of itself.
Example:
```julia
PatLiteral(2)
```
Will match only against values that are equal (using `Base.(==)`) to 2.

```julia
PatLiteral(:a)
```
Will match only against instances of the literal symbol `:a`.
"""
struct PatLiteral{T} <: Pattern
    val::T
end

"""
Type assertions on a [`PatVar`](@ref), will match if and only if 
the type of the matched term for the pattern variable `var` is a subtype 
of `type`.
"""
struct PatTypeAssertion <: Pattern
    var::PatVar
    type::Type
end

struct PatSplatVar <: Pattern
    var::PatVar
end

"""
This type of pattern will match if and only if 
the two subpatterns exist in the same equivalence class,
in the e-graph on which the matching is performed.
**Can be used only in the e-graphs backend**
"""
struct PatEquiv <: Pattern
    left::Pattern
    right::Pattern
end

"""
Term patterns will match
on terms of the same `arity` and with the same 
function symbol (`head`).
"""
struct PatTerm <: Pattern
    head::Any
    args::Vector{Pattern}
    metadata::Union{Nothing, NamedTuple}
end
TermInterface.arity(p::PatTerm) = length(p.args)
PatTerm(head, args) = PatTerm(head, args, nothing)

"""
This pattern type matches on a function application 
but instead of strictly matching on a head symbol, 
it has a pattern variable as head. It can be used for 
example to match arbitrary function calls.
"""
struct PatAllTerm <: Pattern
    head::PatVar
    args::Vector{Pattern}
    metadata::Union{Nothing, NamedTuple}
end
TermInterface.arity(p::PatAllTerm) = length(p.args)
PatAllTerm(head, args) = PatAllTerm(head, args, nothing)

# collect pattern variables in a set of symbols
patvars(p::PatLiteral; s=PatVar[]) = s 
patvars(p::PatVar; s=PatVar[]) = push!(s, p)
patvars(p::PatTypeAssertion; s=PatVar[]) = patvars(p.var; s=s)
patvars(p::PatSplatVar; s=PatVar[]) = patvars(p.var; s=s)

function patvars(p::PatTerm; s=PatVar[])
    for x ∈ p.args 
        patvars(x; s)
    end
    return s
end 

function patvars(p::PatAllTerm; s=PatVar[])
    push!(s, p.head)
    for x ∈ p.args 
        patvars(x; s)
    end
    return s
end 