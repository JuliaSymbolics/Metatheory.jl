# ======================= SHOWING ====================

function Base.show(io::IO, x::Pattern) 
    expr = to_expr(x)
    print(io, expr)
end

# TODO ADD ORIGINAL CODE OF PREDICATE TO PATVAR

function to_expr(x::PatVar)
    if x.predicate == alwaystrue
        Expr(:call, :~, x.name)
    else
        Expr(:call, :~, Expr(:(::), x.name, x.predicate))
    end
end

to_expr(x::Any) = x

function to_expr(x::PatSegment)
    Expr(:call, :~, 
        if x.predicate == alwaystrue
            Expr(:call, :~, x.name)
        else
            Expr(:call, :~, Expr(:(::), x.name, x.predicate))
        end
    )
end

to_expr(x::PatSegment{typeof(alwaystrue)}) = 
    Expr(:call, :~, Expr(:call, :~, Expr(:call, :~, x.name)))
to_expr(x::PatSegment{T}) where {T<:Function} = 
    Expr(:call, :~, Expr(:call, :~, Expr(:(::), x.name, nameof(T))))
to_expr(x::PatSegment{<:Type{T}}) where T = 
    Expr(:call, :~, Expr(:call, :~, Expr(:(::), x.name, T)))

function to_expr(x::PatTerm) 
    pl = operation(x)
    similarterm(Expr, pl, arguments(x); exprhead=exprhead(x))
end
