
"Iterates a function `f` on `datum` until a fixed point is reached where `f(x) == x`"
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
export normalize

"""
Like [`normalize`](@ref) but keeps a vector of hashes to detect cycles,
returns the current datum when a cycle is detected
"""
function normalize_nocycle(f, datum, fargs...; callback=()->())
    hist = UInt[]
    push!(hist, hash(datum))
    x = f(datum, fargs...)
    while hash(x) ∉ hist
        push!(hist, hash(x))
        x = f(x, fargs...)
        callback()
    end
    x
end
export normalize_nocycle
