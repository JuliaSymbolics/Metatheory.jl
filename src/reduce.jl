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

# reduction step relying on MatchCore for codegen
# TODO replace with
function matchcore_match(ex, block, __source__::LineNumberNode, __module__::Module)
    matching = MatchCore.gen_match(quot(ex), block, __source__, __module__)
    matching = MatchCore.AbstractPatterns.init_cfg(matching)
    @debug `Reduction step on $ex`
    matching |> __module__.eval |>
        x -> binarize!(x, :(+)) |>
        x -> binarize!(x, :(*))
end

const MAX_ITER = 1000

## HARD FIX of n-arity of the (*) and (+) operators in Expr trees
function binarize!(e, op::Symbol)
    f(e) = if (isexpr(e, :call) && e.args[1] == op && length(e.args) > 3)
        @info :match e
        foldl((x,y) -> Expr(:call, op, x, y), e.args[2:end])
    else e end

    df_walk!(f, e)
end

function sym_reduce(ex, theory;
    __source__=LineNumberNode(0),
     __module__=@__MODULE__,
    order=:outer # inner expansion
    )

    # n = iteration count. useful to protect against ∞ loops
    # let's use a closure :)
    n = 0
    countit = () -> begin
        n += 1
        n >= MAX_ITER ? error("max reduction iterations exceeded") : nothing
    end

    step = x -> matchcore_match(x, makeblock(theory),  __source__, __module__)
    norm_step = x -> begin
        @debug `Normalization step: $ex`
        res = normalize(step, x; callback=countit)
        @debug `Normalization step RESULT: $res`
        return res
    end

    # evaluation order: outer = suitable for symbolic maths
    # inner = suitable for semantics
    walk! = if order == :inner
        (x, y) -> df_walk!(x,y; skip_call=true)
    elseif order == :outer
        (x, y) -> bf_walk!(x,y; skip_call=true)
    else
        error(`unknown evaluation order $order`)
    end

    normalize(x -> walk!(norm_step, x), ex)
end


# Only works in interactive sessions because it evals theory
macro reduce(ex, theory, order, escape)
    t = nothing
    try t = getfield(__module__, theory)
    catch e error(`theory $theory not found!`) end

    if !(t isa Vector{Rule}) error(`$theory is not a Vector\{Rule\}`) end
    sym_reduce(ex, t; order=order, __source__=__source__, __module__=__module__) |>
        x -> escape ? esc(x) : quot(x)
end

macro reduce(ex, theory) :(@reduce $ex $theory outer false) end

macro reduce(ex, theory, order) :(@reduce $ex $theory false) end

macro ret_reduce(ex, theory) :(@ret_reduce $ex $theory outer true) end
