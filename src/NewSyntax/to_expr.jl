# TODO ADD ORIGINAL CODE OF PREDICATE TO PATVAR

function to_expr(x::PatVar)
    if x.predicate == alwaystrue
        x.name
    else
        Expr(:(::), x.name, x.predicate)
    end
end

to_expr(x::Any) = x

function to_expr(x::PatSegment)
    if x.predicate == alwaystrue
        Expr(:..., x.name)
    else
        Expr(:..., Expr(:(::), x.name, x.predicate))
    end
end

function to_expr(x::PatTerm) 
    pl = operation(x)
    similarterm(Expr, pl, map(to_expr, arguments(x)); exprhead=exprhead(x))
end


function Base.show(io::IO, x::AbstractPat) 
    expr = to_expr(x)
    print(io, expr)
end
