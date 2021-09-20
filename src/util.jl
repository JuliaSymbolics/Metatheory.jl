function binarize(e::T) where {T}
    !istree(e) && return e
    head = exprhead(e)
    if head == :call
        op = operation(e)
        args = arguments(e)
        meta = metadata(e)
        if op ∈ binarize_ops && arity(e) > 2
            return foldl((x,y) -> similarterm(T, op, [x,y], symtype(e); metadata=meta, exprhead=head), args)
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

