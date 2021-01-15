include("theory.jl")

using MatchCore

function normalize(f, datum, fargs...; callback=()->())
    old = datum
    new = f(old, fargs...)
    while new != old
        old = new
        new = f(old, fargs...)
        callback()
    end
    new
end

function reduce_step(ex, block, __source__::LineNumberNode, __module__::Module)
    matching = MatchCore.gen_match(quot(ex), block, __source__, __module__)
    matching = MatchCore.AbstractPatterns.init_cfg(matching)
    @debug `Reduction step on $ex`
    matching |> __module__.eval
end

const MAX_ITER = 1000

function sym_reduce(ex, theory;
    __source__=LineNumberNode(0), __module__=@__MODULE__,
    order=:outer # inner expansion
    )
    # iteration guard! useful to protect against loops
    # let's use a closure :)
    n = 0
    countit = () -> begin
        n += 1
        n >= MAX_ITER ? error("max reduction iterations exceeded") : nothing
    end
    step = x -> reduce_step(x, makeblock(theory),  __source__, __module__)
    norm_step = x -> begin
        @debug `Normalization step: $ex`
        res = normalize(step, x; callback=countit)
        @debug `Normalization step RESULT: $res`
        return res
    end
    # evaluation policy: outer = suitable for symbolic maths
    # inner = suitable for semantics
    walk! = if order == :inner
        (x, y) -> df_walk!(x,y; skip_call=true)
    elseif order == :outer
        (x, y) -> bf_walk!(x,y; skip_call=true)
    else
        error(`unknown evaluation order $order`)
    end

    # try to see big picture patterns first
    normalize(x -> walk!(norm_step, x), ex)
end


# Only works in interactive sessions because it evals theory
macro reduce(ex, theory, order)
    t = nothing
    try t = getfield(__module__, theory)
    catch e error(`theory $theory not found!`) end

    if !(t isa Vector{Rule}) error(`$theory is not a Vector\{Rule\}`) end
    sym_reduce(ex, t; order=order, __source__=__source__, __module__=__module__) |> quot
end

macro reduce(ex, theory) :(@reduce $ex $theory outer) end
