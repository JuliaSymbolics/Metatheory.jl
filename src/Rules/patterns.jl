"""
Abstract type representing a pattern used in all the various pattern matching backends. 
You can use the `Pattern` constructor to recursively convert an `Expr` (or any type satisfying [`Metatheory.TermInterface`](@ref)) to a [`Pattern`](@ref).
"""
abstract type Pattern end

import Base.==
==(a::Pattern, b::Pattern) = false

# TODO implement debrujin indexing?
"""
Pattern variables will first match on any subterm
and instantiate the substitution to that subterm. 
"""
struct PatVar <: Pattern
    var::Symbol
end
==(a::PatVar, b::PatVar) = (a.var == b.var)

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
==(a::PatLiteral, b::PatLiteral) = (a.val == b.val)

"""
Type assertions on a [`PatVar`](@ref), will match if and only if 
the type of the matched term for the pattern variable `var` is a subtype 
of `type`.
"""
struct PatTypeAssertion <: Pattern
    var::PatVar
    type::Type
end
function ==(a::PatTypeAssertion, b::PatTypeAssertion)
    (a.var == b.var) && (a.type == b.type)
end

struct PatSplatVar <: Pattern
    var::PatVar
end
==(a::PatSplatVar, b::PatSplatVar) = (a.var == b.var)


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
function ==(a::PatEquiv, b::PatEquiv)
    (a.left == b.left) && (a.right == b.right)
end

"""
Term patterns will match
on terms of the same `arity` and with the same 
function symbol (`head`).
"""
struct PatTerm <: Pattern
    head::Any
    args::Vector{Pattern}
    metadata::NamedTuple
end
TermInterface.arity(p::PatTerm) = length(p.args)
PatTerm(head, args) = PatTerm(head, args, (;))
function ==(a::PatTerm, b::PatTerm)
    (a.head == b.head) && all(a.args .== b.args) && (a.metadata == b.metadata)
end

"""
This pattern type matches on a function application 
but instead of strictly matching on a head symbol, 
it has a pattern variable as head. It can be used for 
example to match arbitrary function calls.
"""
struct PatAllTerm <: Pattern
    head::PatVar
    args::Vector{Pattern}
    metadata::NamedTuple
end
TermInterface.arity(p::PatAllTerm) = length(p.args)
PatAllTerm(head, args) = PatAllTerm(head, args, (;))
function ==(a::PatAllTerm, b::PatAllTerm)
    (a.head == b.head) && all(a.args .== b.args) && (a.metadata == b.metadata)
end

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