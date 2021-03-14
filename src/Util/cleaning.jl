# FIXME this thing eats up macro calls!
"""
Remove LineNumberNode from quoted blocks of code
"""
rmlines(e::Expr) = Expr(e.head, map(rmlines, filter(x -> !(x isa LineNumberNode), e.args))...)
rmlines(a) = a

"""
HARD FIX of n-arity of operators in `Expr` trees
"""
function binarize_step(e, ops::Vector{Symbol})
    if !(e isa Expr) return e end
    op = e.args[1]
    if (isexpr(e, :call) && op ∈ ops && length(e.args) > 3)
        foldl((x,y) -> Expr(:call, op, x, y), e.args[2:end])
    else
        e
    end
end

function binarize!(e, ops::Vector{Symbol})
    df_walk!(binarize_step, e, ops)
end

function clean_block_step(e)
    if isexpr(e, :block)
        if length(e.args) == 1
            return e.args[1]
        elseif length(e.args) > 3
            return foldl((x,y) -> Expr(:block, x, y), e.args[2:end])
        end
    end
    return e
end

function cleanblock(e)
    df_walk!(clean_block_step, e)
end

const binarize_ops = [:(+), :(*)]
"""
Binarize n-ary operators (`+` and `*`) and call [`rmlines`](@ref)
"""
cleanast(ex) = rmlines(ex)  |>
    x -> binarize!(x, binarize_ops)


interp_dol(ex::Expr, mod::Module) =
    Meta.isexpr(ex, :$) ? mod.eval(ex.args[1]) : ex
interp_dol(any, mod::Module) = any

function interpolate_dollar(ex, mod::Module)
    df_walk(interp_dol, ex, mod)
end


remove_assertions(e) = df_walk( x -> (isexpr(x, :(::)) ? x.args[1] : x),
    e; skip_call=true )

unquote_sym(e) = df_walk( x -> (x isa QuoteNode && x.value isa Symbol ? x.value : x),
    e; skip_call=true )
