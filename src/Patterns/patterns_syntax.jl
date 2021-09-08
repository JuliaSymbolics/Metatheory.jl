# ======================= SHOWING ====================

function Base.show(io::IO, x::Pattern) 
    expr = to_expr(x)
    print(io, expr)
end

to_expr(x::PatVar) = x.name

to_expr(x::PatLiteral) =
    if x.val isa Symbol
        QuoteNode(x.val)
    else
        x.val
    end

function to_expr(x::PatTypeAssertion) 
    Expr(Symbol("::"), to_expr(x.var), x.type)
end

function to_expr(x::PatSplatVar) 
    Expr(Symbol("..."), to_expr(x.var))
end

function to_expr(x::PatEquiv) 
    Expr(:call, Symbol("≡ₙ"), to_expr(x.left), to_expr(x.right))
end

function to_expr(x::PatTerm) 
    if x.head == :call && length(x.args) >= 1
        Expr(:call, x.args[1].val, to_expr.(x.args[2:end])...)
    else
        Expr(x.head, to_expr.(x.args)...)
    end
end

function to_expr(x::PatAllTerm) 
    # TODO change me ?
    head = Symbol("~", x.head.name)
    Expr(:call, head, to_expr.(x.args)...)
end


# ======================= READING ====================

# Resolve `GlobalRef` instances to literals.
resolve(gr::GlobalRef) = getproperty(gr.mod, gr.name)
resolve(gr) = gr

function Pattern(ex::Expr, mod=@__MODULE__, resolve_fun=false)
    ex = cleanast(ex)
    head = operation(ex)
    args = arguments(ex)

    n = length(args)
    patargs = Vector{Pattern}(undef, n)
    for i ∈ 1:n
        @inbounds patargs[i] = Pattern(args[i], mod, resolve_fun)
    end

    if head == :call
        if resolve_fun
            f = resolve(GlobalRef(mod, args[1]))
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
    if ex isa Expr 
        ex = cleanast(ex)
    end
    if istree(typeof(ex))
        head = operation(ex)
        args = arguments(ex)

        n = length(args)
        patargs = Vector{Pattern}(undef, n)
        for i ∈ 1:n
            @inbounds patargs[i] = Pattern(args[i], mod, resolve_fun)
        end

        return PatTerm(head, patargs)
    end
    return PatLiteral(ex)
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
