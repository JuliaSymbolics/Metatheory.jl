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
    pl = operation(x)
    similarterm(Expr, pl, arguments(x); exprhead=exprhead(x))
end

function to_expr(x::PatAllTerm) 
    # TODO change me ?
    head = Symbol("~", x.head.name)
    Expr(:call, head, to_expr.(x.args)...)
end