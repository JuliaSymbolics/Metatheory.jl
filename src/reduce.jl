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
    res = MatchCore.gen_match(quot(ex), block, __source__, __module__)
    res = MatchCore.AbstractPatterns.init_cfg(res)
    res |> eval
end

const MAX_ITER = 1000

function sym_reduce(ex, theory; __source__=LineNumberNode(0), __module__=@__MODULE__)
    # iteration guard! useful to protect against loops
    # let's use a closure :)
    n = 0
    countit = () -> begin
        n += 1
        n >= MAX_ITER ? error("max reduction iterations exceeded") : nothing
    end
    step = x -> reduce_step(x, theory.patternblock,  __source__, __module__)
    norm_step = x -> normalize(step, x; callback=countit)
    # try to see big picture patterns first
    normalize(x -> bf_walk!(norm_step, x), ex)
end

# Only works in interactive sessions because it evals theory
macro reduce(ex, theory)
    t = getfield(__module__, theory)
    sym_reduce(ex, t; __source__=__source__, __module__=__module__) |> quot
end
