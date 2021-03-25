# TODO document custom types as patterns

abstract type Pattern end

# TODO implement debrujin indexing?
struct PatVar <: Pattern
    var::Symbol
end
Base.show(io::IO, x::PatVar) = print(io, x.var)

# TODO parametrize by T?
struct PatLiteral <: Pattern
    val::Any
end
function Base.show(io::IO, x::PatLiteral)
    if x.val isa Symbol 
        print(io, ":")
    end
    print(io, x.val)
end

struct PatTypeAssertion <: Pattern
    var::PatVar
    type::Type
end
Base.show(io::IO, x::PatTypeAssertion) = print(io, x.var, "::", x.type)

struct PatSplatVar <: Pattern
    var::PatVar
end
Base.show(io::IO, x::PatSplatVar) = print(io, x.var, "...")


struct PatTerm <: Pattern
    head::Any
    args::Vector{Pattern}
    metadata::Union{Nothing, NamedTuple}
end
# TODO fancy print binary op calls
function Base.show(io::IO, x::PatTerm)
    n = length(x.args)
    if x.head isa Symbol 
        if Base.isbinaryoperator(x.head) && n == 2
            print(io, x.args[1], x.head, x.args[2])
            return
        elseif Base.isunaryoperator(x.head) && n == 1
            print(io, x.head, x.args[1])
            return
        end
    end

    print(io, x.head)
    print(io, "(")
    for i ∈ 1:n
        @inbounds print(io, x.args[i])
        if i < n
            print(io, ",")
        end
    end
    print(io, ")")
end
TermInterface.arity(p::PatTerm) = length(p.args)
# =================== RULE SYNTAX ===============
# from Julia AST to Pattern

"""
Recursively convert an [`Expr`](@ref) to a [`Pattern`](@ref) 
"""
function Pattern(ex::Expr)
    ex = preprocess(ex)
    head = gethead(ex)
    args = getargs(ex)
    meta = getmetadata(ex)

    n = length(args)
    patargs = Vector{Pattern}(undef, n)
    for i ∈ 1:n
        @inbounds patargs[i] = Pattern(args[i])
    end

    # is a Type assertion 
    if head == :(::) && meta.iscall == false
        v = patargs[1]
        t = patargs[2]
        if v isa PatVar && t isa PatLiteral
            return PatTypeAssertion(v, t.val)
        end
    end

    if head == :(...) && meta.iscall == false
        v = patargs[1]
        if v isa PatVar
            return PatSplatVar(v)
        end
    end


    PatTerm(head, patargs, meta)
end

function Pattern(x::Symbol)
    PatVar(x)
end

function Pattern(x::QuoteNode)
    if x.value isa Symbol
        PatLiteral(x.value) 
    else
        PatLiteral(x) 
    end
end

# Generic fallback
function Pattern(ex)
    ex = preprocess(ex)

    if istree(ex)
        head = gethead(ex)
        args = getargs(ex)
        meta = getmetadata(ex)

        n = length(args)
        patargs = Vector{Pattern}(undef, n)
        for i ∈ 1:n
            @inbounds patargs[i] = makepat(args[i])
        end
        PatTerm(head, patargs, meta)
    end
    PatLiteral(ex)
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