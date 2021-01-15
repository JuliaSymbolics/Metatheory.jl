## Operator Overloading
# TODO test
macro extend_operator(op, theory, order)
    try
        t = getfield(__module__, theory)
    catch e
        error(`theory $theory not found!`)
    end
    if !(Base.isbinaryoperator(op))
        error(`($op) is not a binary operator`)
    end
    if(order == :inner)
        inner = true
    elseif(order == :outer)
        inner = false
    else
        error(`invalid evaluation order '$order', expected 'inner' or 'outer'`)

    quote
        function $(op)(x::Symbol, y)
            ex = :(($op)())

            # todo take this call out of here
            sym_reduce(ex, t; ) end
        end
    end

end
