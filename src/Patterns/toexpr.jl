# ======================= SHOWING ====================

function Base.show(io::IO, x::Pattern) 
    expr = to_expr(x)
    print(io, expr)
end

to_expr(x::PatVar{typeof(alwaystrue)}) = Expr(:call, :~, x.name)
to_expr(x::PatVar{T}) where {T<:Function} = 
    Expr(:call, :~, Expr(:(::), x.name, nameof(T)))

to_expr(x::PatVar{<:Type{T}}) where T = 
    Expr(:call, :~, Expr(:(::), x.name, T))

to_expr(x::Any) = x

to_expr(x::PatSegment{typeof(alwaystrue)}) = 
    Expr(:call, :~, Expr(:call, :~, Expr(:call, :~, x.name)))
to_expr(x::PatSegment{T}) where {T<:Function} = 
    Expr(:call, :~, Expr(:call, :~, Expr(:(::), x.name, nameof(T))))
to_expr(x::PatVar{<:Type{T}}) where T = 
    Expr(:call, :~, Expr(:call, :~, Expr(:(::), x.name, T)))

function to_expr(x::PatTerm) 
    pl = operation(x)
    similarterm(Expr, pl, arguments(x); exprhead=exprhead(x))
end
