# FIXME this thing eats up macro calls!
"""
Remove LineNumberNode from quoted blocks of code
"""
rmlines(e::Expr) = Expr(e.head, map(rmlines, filter(x -> !(x isa LineNumberNode), e.args))...)
rmlines(a) = a

# TODO binarize block?
"""
HARD FIX of n-arity of operators in `Expr` trees.
"""
function binarize!(e, ops::Vector{Symbol})
    if !(e isa Expr)
        return e
    end

    start = isexpr(e, :call) ? 2 : 1
    n = length(e.args)

    for i ∈ start:n
        e.args[i] = binarize!(e.args[i], ops)
    end

    if isexpr(e, :call)
        op = e.args[1]
        if op ∈ ops && length(e.args) > 3
            return foldl((x,y) -> Expr(:call, op, x, y), @view e.args[2:end])
        end
    end
    return e
end

# function binarize!(e, ops::Vector{Symbol})
#     df_walk!(binarize_step, e, ops)
# end

function clean_block_step(e)
    if isexpr(e, :block)
        if length(e.args) == 1
            return e.args[1]
        elseif length(e.args) > 3
            return foldl((x,y) -> Expr(:block, x, y), @view e.args[2:end])
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
cleanast_rec(ex) = rmlines(ex)  |>
    x -> binarize!(x, binarize_ops)



function cleanast(e::Expr)
    # TODO better line removal 
    if isexpr(e, :block)
        return Expr(e.head, filter(x -> !(x isa LineNumberNode), e.args)...)
    end

    # Binarize
    if isexpr(e, :call)
        op = e.args[1]
        if op ∈ binarize_ops && length(e.args) > 3
            return foldl((x,y) -> Expr(:call, op, x, y), @view e.args[2:end])
        end
    end
    return e
end


function cleanast!(e::Expr)
    # TODO better line removal 
    if isexpr(e, :block)
        e.args = filter(x -> !(x isa LineNumberNode), e.args)
    end

    # Binarize
    if isexpr(e, :call)
        op = e.args[1]
        if op ∈ binarize_ops && length(e.args) > 3
            ne = foldl((x,y) -> Expr(:call, op, x, y), @view e.args[2:end])
            e.args = ne.args
        end
    end
    return e
end





remove_assertions(e) = df_walk( x -> (isexpr(x, :(::)) ? x.args[1] : x),
    e; skip_call=true )

unquote_sym(e) = df_walk( x -> (x isa QuoteNode && x.value isa Symbol ? x.value : x),
    e; skip_call=true )

function collect_symbols(ex)
    syms = Set{Symbol}()
    df_walk( x -> (if x isa Symbol; push!(syms, x); end; x), ex; skip_call=true )
    syms
end