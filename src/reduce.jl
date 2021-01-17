include("theory.jl")

using MatchCore
using GeneralizedGenerated
using RuntimeGeneratedFunctions

RuntimeGeneratedFunctions.init(@__MODULE__)


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


## HARD FIX of n-arity of the (*) and (+) operators in Expr trees
function binarize!(e, op::Symbol)
    f(e) = if (isexpr(e, :call) && e.args[1] == op && length(e.args) > 3)
        foldl((x,y) -> Expr(:call, op, x, y), e.args[2:end])
    else e end

    df_walk!(f, e)
end

# RETURNS A QUOTED CLOSURE WITH THE GENERATED MATCHING CODE! FASTER AF! 🔥
# reduction step relying on MatchCore for codegen
# TODO replace with
function matchcore_match(block, __source__, __module__)
    parameter = Meta.gensym(:reducing_expression)

    matching = MatchCore.gen_match(parameter, block, __source__, __module__)
    matching = MatchCore.AbstractPatterns.init_cfg(matching)

    ex = :(($parameter) -> $matching)
    println(ex)
    @RuntimeGeneratedFunction(ex)
    #mk_function([parameter], [], matching)
end

function closurize(block, __source__, __module__)
    mk_function(__module__, :(
        param ->
        #matching =
        #matching =
        MatchCore.AbstractPatterns.init_cfg(MatchCore.gen_match(param, block, __source__, __module__)))
    )
end

const MAX_ITER = 1000


function sym_reduce(ex, theory;
    __source__=LineNumberNode(0),
    order=:outer, # inner expansion
    m::Module=@__MODULE__
    )

    # n = iteration count. useful to protect against ∞ loops
    # let's use a closure :)
    n = 0
    countit = () -> begin
        n += 1
        n >= MAX_ITER ? error("max reduction iterations exceeded") : nothing
    end

    # matcher IS A CLOSURE WITH THE GENERATED MATCHING CODE! FASTER AF! 🔥
    #matcher = matchcore_match(makeblock(theory),  __source__, m) |> eval
    matcher = matchcore_match(makeblock(theory),  __source__, m)
    #step = x -> Base.invokelatest(matcher, x) |>
    step = x -> matcher(x) |>
        x -> binarize!(x, :(+)) |>
        x -> binarize!(x, :(*))

    norm_step = x -> begin
        @debug `Normalization step: $ex`
        res = normalize(step, x; callback=countit)
        @debug `Normalization step RESULT: $res`
        return res
    end

    # evaluation order: outer = suitable for symbolic maths
    # inner = suitable for semantics
    walk = if order == :inner
        (x, y) -> df_walk(x,y; skip_call=true)
    elseif order == :outer
        (x, y) -> bf_walk(x,y; skip_call=true)
    else
        error(`unknown evaluation order $order`)
    end

    normalize(x -> walk(norm_step, x), ex)
end


macro reduce(ex, theory, order, escape)
    t = nothing
    try t = getfield(__module__, theory)
    catch e error(`theory $theory not found!`) end

    if !(t isa Vector{Rule}) error(`$theory is not a Vector\{Rule\}`) end
    sym_reduce(ex, t; order=order, __source__=__source__, m=__module__) |>
        x -> escape ? esc(x) : quot(x)
end

macro reduce(ex, theory) :(@reduce $ex $theory outer false) end
macro reduce(ex, theory, order) :(@reduce $ex $theory $order false) end

macro ret_reduce(ex, theory, order, escape)
    t = nothing
    try t = getfield(__module__, theory)
    catch e error(`theory $theory not found!`) end
    if !(t isa Vector{Rule}) error(`$theory is not a Vector\{Rule\}`) end
    sym_reduce(ex, t; order=order, __source__=__source__, m=__module__)
end
macro ret_reduce(ex, theory) :(@ret_reduce $ex $theory outer true) end
macro ret_reduce(ex, theory, order) :(@ret_reduce $ex $theory $order true) end
