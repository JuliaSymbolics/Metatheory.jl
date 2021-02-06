const TIMEOUT = 1000

function rewrite(ex, theory::Theory;
        __source__=LineNumberNode(0),
        order=:inner,                   # evaluation order
        m::Module=@__MODULE__,
		timeout::Int=TIMEOUT
    )
    ex=cleanast(ex)

	if !(theory isa Function)
		theory = compile_theory(theory, m; __source__=__source__)
	end

    # n = iteration count. useful to protect against ∞ loops
    # let's use a closure :)
    n = 0
    countit = () -> begin
        n += 1
        n >= timeout ? error("max reduction iterations exceeded") : nothing
    end

    step = x -> cleanast(theory(x, m))
    norm_step = x -> normalize_nocycle(step, x; callback=countit)

    # evaluation order: outer = suitable for symbolic maths
    # inner = suitable for semantics
    walk = if order == :inner
        (x, y) -> df_walk!(x,y; skip_call=true)
    elseif order == :outer
        (x, y) -> bf_walk!(x,y; skip_call=true)
    else
        error(`unknown evaluation order $order`)
    end

    normalize_nocycle(x -> walk(norm_step, x), ex; )
end


macro rewrite(ex, theory, order)
	t = gettheory(theory, __module__)
    rewrite(ex, t; order=order, __source__=__source__, m=__module__) |> quot
end
macro rewrite(ex, theory) :(@rewrite $ex $theory outer) end

# escapes the expression instead of returning it.
macro esc_rewrite(ex, theory, order)
	t = gettheory(theory, __module__)
    rewrite(ex, t; order=order, __source__=__source__, m=__module__) |> esc
end
macro esc_rewrite(ex, theory) :(@ret_reduce $ex $theory outer) end


macro rewriter(te, order)
	t = gettheory(theory, __module__)
	quote (ex) -> rewrite(ex, $t;
			order=$order, __source__=$__source__, m=$__module__)
	end
end
