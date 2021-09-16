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
function binarize!(e, ops::Vector)
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




const binarize_ops = [:(+), :(*), (+), (*)]




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
