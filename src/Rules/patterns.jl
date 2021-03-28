# TODO document custom types as patterns

abstract type Pattern end

# TODO implement debrujin indexing?
struct PatVar <: Pattern
    var::Symbol
end

# TODO parametrize by T?
struct PatLiteral{T} <: Pattern
    val::T
end


struct PatTypeAssertion <: Pattern
    var::PatVar
    type::Type
end

struct PatSplatVar <: Pattern
    var::PatVar
end

# only available in EGraphs
struct PatEquiv <: Pattern
    left::Pattern
    right::Pattern
end


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