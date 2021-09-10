
# ======================= READING ====================

# Resolve `GlobalRef` instances to literals.
resolve(gr::GlobalRef) = getproperty(gr.mod, gr.name)
resolve(gr) = gr



function Pattern(ex, mod=@__MODULE__, resolve_fun=false)
    if !istree(ex)
        return PatLiteral(ex)
    end

    if ex isa Expr 
        ex = cleanast(ex)
    end
    head = exprhead(ex)
    op = operation(ex)
    args = arguments(ex)

    if istree(op)
        error("Cannot yet match on composite expressions as function symbols")
    end

    if resolve_fun && op isa Symbol
        op = resolve(GlobalRef(mod, f))
    end

    patargs = map(i -> Pattern(i, mod, resolve_fun), args)
    
    if head == :(::)
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

    PatTerm(head, op, patargs)
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

function Pattern(p::Pattern, mod=@__MODULE__, resolve_fun=false)
    p 
end

macro pat(ex)
    Pattern(ex, __module__, false)
end

macro pat(ex, resolve_fun::Bool)
    Pattern(ex, __module__, resolve_fun)
end
