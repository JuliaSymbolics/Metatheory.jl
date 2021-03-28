# ======================= SHOWING ====================

Base.show(io::IO, x::PatVar) = print(io, x.var)

function Base.show(io::IO, x::PatLiteral)
    if x.val isa Symbol 
        print(io, ":")
    end
    print(io, x.val)
end

Base.show(io::IO, x::PatTypeAssertion) = print(io, x.var, "::", x.type)

Base.show(io::IO, x::PatSplatVar) = print(io, x.var, "...")

Base.show(io::IO, x::PatEquiv) = print(io, x.left, "≡ₙ", x.right)

function Base.show(io::IO, x::PatTerm)
    n = length(x.args)
    if x.head isa Symbol 
        if Base.isbinaryoperator(x.head) && n == 2
            print(io, "(", x.args[1], x.head, x.args[2], ")")
            return
        elseif Base.isunaryoperator(x.head) && n == 1
            print(io, "(", x.head, x.args[1], ")")
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

function Pattern(p::Pattern)
    p 
end

macro pat(ex)
    Pattern(ex)
end
