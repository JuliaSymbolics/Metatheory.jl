# FIXME this thing eats up macro calls!
"""
Remove LineNumberNode from quoted blocks of code
"""
rmlines(e::Expr) = Expr(e.head, map(rmlines, filter(x -> !(x isa LineNumberNode), e.args))...)
rmlines(a) = a

"""
HARD FIX of n-arity of operators in `Expr` trees
"""
function binarize!(e, op::Symbol)
    f(e) = if (isexpr(e, :call) && e.args[1] == op && length(e.args) > 3)
        foldl((x,y) -> Expr(:call, op, x, y), e.args[2:end])
    else e end

    df_walk!(f, e)
end

"""
Binarize n-ary operators (`+` and `*`) and call [`rmlines`](@ref)
"""
cleanast(ex) = rmlines(ex) |>
    x -> binarize!(x, :(+)) |>
    x -> binarize!(x, :(*))


interp_dol(ex::Expr, mod::Module) =
    Meta.isexpr(ex, :$) ? mod.eval(ex.args[1]) : ex
interp_dol(any, mod::Module) = any

function interpolate_dollar(ex, mod::Module)
    df_walk(interp_dol, ex, mod)
end


remove_assertions(e) = df_walk( x -> (isexpr(x, :(::)) ? x.args[1] : x), e; skip_call=true )
