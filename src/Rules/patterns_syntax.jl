# ======================= SHOWING ====================

Base.show(io::IO, x::PatVar) = print(io, x.name)

function Base.show(io::IO, x::PatLiteral)
    if x.val isa Symbol 
        print(io, ":")
    end
    print(io, x.val)
end

Base.show(io::IO, x::PatTypeAssertion) = print(io, x.var, "::", x.type)

Base.show(io::IO, x::PatSplatVar) = print(io, x.name, "...")

Base.show(io::IO, x::PatEquiv) = print(io, x.left, "≡ₙ", x.right)

function Base.show(io::IO, x::PatTerm)
    if x.head == :call
        @assert x.args[1] isa PatLiteral
        print(io, Expr(x.head, x.args[1].val, x.args[2:end]...))
    else 
        print(io, Expr(x.head, x.args...))
    end
end

function Base.show(io::IO, x::PatAllTerm)
    n = length(x.args)

    # TODO change me ?
    print(io, "~", x.head)
    print(io, "(")
    for i ∈ 1:n
        @inbounds print(io, x.args[i])
        if i < n
            print(io, ",")
        end
    end
    print(io, ")")
end


# ======================= READING ====================


function Pattern(ex::Expr, mod=@__MODULE__, resolve_fun=false)
    ex = preprocess(ex)
    head = gethead(ex)
    args = getargs(ex)

    n = length(args)
    patargs = Vector{Pattern}(undef, n)
    for i ∈ 1:n
        @inbounds patargs[i] = Pattern(args[i], mod, resolve_fun)
    end

    if head == :call
        # println(:aaa)
        if resolve_fun
            fname = args[1]
            f = mod.eval(fname)
            patargs[1] = PatLiteral(f)
        else
            patargs[1] = PatLiteral(args[1])
        end
    elseif head == :(::)
        v = patargs[1]
        t = patargs[2]
        ty = Union{}
        if t isa PatVar
            ty = getfield(mod, t.name)
        elseif t isa PatLiteral{<:Type}
            ty = t.val
        end
        return PatTypeAssertion(v, ty)
    elseif head == :(...)
        v = patargs[1]
        if v isa PatVar
            return PatSplatVar(v)
        end
    end


    PatTerm(head, patargs)
end

function Pattern(x::Symbol, mod=@__MODULE__, resolve_fun=false)
    PatVar(x)
end

function Pattern(x::QuoteNode, mod=@__MODULE__, resolve_fun=false)
    if x.value isa Symbol
        PatLiteral(x.value) 
    else
        PatLiteral(x) 
    end
end

# Generic fallback
function Pattern(ex, mod=@__MODULE__, resolve_fun=false)
    ex = preprocess(ex)
    if istree(ex)
        head = gethead(ex)
        args = getargs(ex)

        n = length(args)
        patargs = Vector{Pattern}(undef, n)
        for i ∈ 1:n
            @inbounds patargs[i] = Pattern(args[i], mod, resolve_fun)
        end

        PatTerm(head, patargs)
    end
    PatLiteral(ex)
end

function Pattern(p::Pattern, mod=@__MODULE__, resolve_fun=false)
    p 
end

macro pat(ex)
    Pattern(ex, __module__, false)
end

macro pat(ex, resolve_fun::Bool)
    Pattern(ex, __module__, resolve_fun)
end
