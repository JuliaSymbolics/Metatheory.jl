# ======================= SHOWING ====================

Base.show(io::IO, x::PatVar) = print(io, x.var)

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
    if x.metadata !== nothing && haskey(x.metadata, :iscall) && x.metadata.iscall
        print(io, Expr(:call, x.head, x.args...))
    else 
        print(io, Expr(x.head, x.args...))
    end

    # show(io, Expr(x.head, x.args...))
    # n = length(x.args)
    # if x.head isa Symbol 
    #     if Base.isbinaryoperator(x.head) && n == 2
    #         print(io, "(", x.args[1], x.head, x.args[2], ")")
    #         return
    #     elseif Base.isunaryoperator(x.head) && n == 1
    #         print(io, "(", x.head, x.args[1], ")")
    #         return
    #     end
    # end

    # print(io, x.head)
    # print(io, "(")
    # for i ∈ 1:n
    #     @inbounds print(io, x.args[i])
    #     if i < n
    #         print(io, ",")
    #     end
    # end
    # print(io, ")")
end

function Base.show(io::IO, x::PatAllTerm)
    n = length(x.args)

    # TODO change me
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


function Pattern(ex::Expr, mod=@__MODULE__)
    ex = preprocess(ex)
    head = gethead(ex)
    args = getargs(ex)
    meta = getmetadata(ex)

    n = length(args)
    patargs = Vector{Pattern}(undef, n)
    for i ∈ 1:n
        @inbounds patargs[i] = Pattern(args[i], mod)
    end

    # is a Type assertion 
    if head == :(::) && meta.iscall == false
        v = patargs[1]
        t = patargs[2]
        ty = Union{}
        if t isa PatVar
            ty = getfield(mod, t.name)
        elseif t isa PatLiteral{<:Type}
            ty = t.val
        end
        return PatTypeAssertion(v, ty)
    end

    if head == :(...) && meta.iscall == false
        v = patargs[1]
        if v isa PatVar
            return PatSplatVar(v)
        end
    end


    PatTerm(head, patargs, meta)
end

function Pattern(x::Symbol, mod=@__MODULE__)
    PatVar(x)
end

function Pattern(x::QuoteNode, mod=@__MODULE__)
    if x.value isa Symbol
        PatLiteral(x.value) 
    else
        PatLiteral(x) 
    end
end

# Generic fallback
function Pattern(ex, mod=@__MODULE__)
    ex = preprocess(ex)

    if istree(ex)
        head = gethead(ex)
        args = getargs(ex)
        meta = getmetadata(ex)

        n = length(args)
        patargs = Vector{Pattern}(undef, n)
        for i ∈ 1:n
            @inbounds patargs[i] = Pattern(args[i], mod)
        end
        PatTerm(head, patargs, meta)
    end
    PatLiteral(ex)
end

function Pattern(p::Pattern, mod=@__MODULE__)
    p 
end

macro pat(ex)
    Pattern(ex, __module__)
end
