const TIMEOUT = 1000

"""
This function executes a classical rewriting
algorithm on a Julia expression `ex`. Classical rewriting
applies rule in order with a fixed point iteration:

This algorithm heavily relies on
[RuntimeGeneratedFunctions.jl](https://github.com/SciML/RuntimeGeneratedFunctions.jl)
and the [MatchCore](https://github.com/SciML/RuntimeGeneratedFunctions.jl)
pattern matcher.
**NOTE**: this does not involve the use of [`EGraphs.EGraph`](@ref) or
equality saturation ([`EGraphs.saturate!`](@ref)).
When using `rewrite`, be aware of infinite loops:
Since rules are matched in order in every iteration, it
is possible that commonly used symbolic rules such as commutativity
or associativity of operators may cause this algorithm to
have a cycling computation instantly. This algorithm
detects cycling computation by keeping an history of hashes,
and instantly returns when a cycle is detected.

This algorithm is suitable for simple, deterministic symbolic rewrites.
For more advanced use cases, where it is needed to apply multiple
rewrites at the same time, or it is known that rules are causing loops,
please use [`EGraphs.EGraph`](@ref) and
equality saturation ([`EGraphs.saturate!`](@ref)).
"""
function rewrite(ex, theory::Theory;
        __source__=LineNumberNode(0),
        order=:inner,                   # evaluation order
        m::Module=@__MODULE__,
		timeout::Int=TIMEOUT
    )
    ex=cleanast(ex)

	if !(theory isa Function)
		theory = gettheoryfun(theory, m)
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
	t = gettheory(te, __module__)
	quote (ex) -> rewrite(ex, $t;
			order=$order, __source__=$__source__, m=$__module__)
	end
end
