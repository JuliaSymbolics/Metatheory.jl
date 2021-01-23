const MAX_ITER = 1000

function sym_reduce(ex, theory::Vector{Rule};
        __source__=LineNumberNode(0),
        order=:outer,                   # evaluation order
        m::Module=@__MODULE__
    )

    # matcher IS A CLOSURE WITH THE GENERATED MATCHING CODE! FASTER AF! 🔥
    matcher = compile_theory(theory, m; __source__=__source__)
    sym_reduce(ex, matcher; __source__=__source__, order=order, m=m)
end


cleanast(ex) = rmlines(ex) |>
    x -> binarize!(x, :(+)) |>
    x -> binarize!(x, :(*))

function sym_reduce(ex, matcher::Function;
        __source__=LineNumberNode(0),
        order=:outer,                   # evaluation order
        m::Module=@__MODULE__
    )
    ex=cleanast(ex)

    # n = iteration count. useful to protect against ∞ loops
    # let's use a closure :)
    n = 0
    countit = () -> begin
        n += 1
        n >= MAX_ITER ? error("max reduction iterations exceeded") : nothing
    end

    #step = x -> Base.invokelatest(matcher, x) |>
    step = x -> matcher(x, m) |> cleanast

    norm_step = x -> begin
        @debug `Normalization step: $ex`
        res = normalize(step, x; callback=countit)
        @debug `Normalization step RESULT: $res`
        return res
    end

    # evaluation order: outer = suitable for symbolic maths
    # inner = suitable for semantics
    walk = if order == :inner
        (x, y) -> df_walk!(x,y; skip_call=true)
    elseif order == :outer
        (x, y) -> bf_walk!(x,y; skip_call=true)
    else
        error(`unknown evaluation order $order`)
    end

    normalize(x -> walk(norm_step, x), ex)
end


macro reduce(ex, theory, order)
    if !isdefined(__module__, theory) error(`theory $theory not found!`) end
    t = getfield(__module__, theory)

    if !(t isa Vector{Rule}) error(`$theory is a $(typeof(theory)), not a Vector\{Rule\}`) end
    sym_reduce(ex, t; order=order, __source__=__source__, m=__module__) |> quot
end
macro reduce(ex, theory) :(@reduce $ex $theory outer) end

# escapes the expression instead of returning it.
macro ret_reduce(ex, theory, order)
    if !isdefined(__module__, theory) error(`theory $theory not found!`) end
    t = getfield(__module__, theory)
    if !(t isa Vector{Rule}) error(`$theory is not a Vector\{Rule\}`) end
    sym_reduce(ex, t; order=order, __source__=__source__, m=__module__) |> esc
end
macro ret_reduce(ex, theory) :(@ret_reduce $ex $theory outer) end


macro reducer(te, order)
    if Meta.isexpr(te, :block) # @matcher begine rules... end
		te = rmlines(te)
        t = compile_theory(te.args .|> Rule, __module__)
    else
        #if !isdefined(__module__, te) error(`theory $te not found!`) end
        #t = getfield(__module__, te)
		t = Core.eval(__module__, te)
		if t isa Vector{Rule}; t = compile_theory(t, __module__) end
		println(typeof(t))
		println(t isa Function)
        if !(t isa Function) error(`$te is not a valid theory`) end
    end

	quote
		(ex) ->
			sym_reduce(ex, $t; order=$order, __source__=$__source__, m=$__module__)
	end
end
