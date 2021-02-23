# FIXME this thing eats up macro calls!
"""
Remove LineNumberNode from quoted blocks of code
"""
rmlines(e::Expr) = Expr(e.head, filter(!isnothing, map(rmlines, e.args))...)
rmlines(a) = a
rmlines(x::LineNumberNode) = nothing

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
