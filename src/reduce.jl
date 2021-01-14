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
    #println(res)
    res = MatchCore.AbstractPatterns.init_cfg(res)
    res |> eval
end

const MAX_ITER = 1000

macro reduce(ex, theory)
    t = eval(theory)


    # iteration guard! useful to protect against loops
    # let's use a closure :)
    n = 0
    countit = () -> begin
        n += 1
        n >= MAX_ITER ? error("max reduction iterations exceeded") : nothing
    end

    step = x -> reduce_step(x, t.patternblock,  __source__, __module__)
    norm_step = x -> (println(x);normalize(step, x; callback=countit))
    # try to see big picture patterns first

    #ex = df_walk!(norm_step, ex)
    #ex = bf_walk!(norm_step, ex)

    normalize(x -> bf_walk!(norm_step, x), ex) |> quot

    #reduce_loop(ex, t.patternblock, step) |> quot
end
