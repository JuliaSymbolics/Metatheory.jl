"""
Depth First Walk (Tree Postwalk) on expressions, mutates expression in-place.
"""
function df_walk!(f, e, f_args...; skip=Vector{Symbol}(), skip_call=false)
    if !(e isa Expr) || e.head ∈ skip
        return f(e, f_args...)
    end
    #println("walking on", e)
    start = 1
    # skip walking on function names
    if skip_call && isexpr(e, :call)
        start = 2
    end
    e.args[start:end] = e.args[start:end] .|> x ->
        df_walk!(f, x, f_args...; skip=skip, skip_call=skip_call)
    return f(e, f_args...)
end

"""
Depth First Walk (Tree Postwalk) on expressions. Does not mutate expressions.
"""
function df_walk(f, e, f_args...; skip=Vector{Symbol}(), skip_call=false)
    ne = e isa Expr ? copy(e) : e
    df_walk_rec(f, ne, f_args...; skip=skip, skip_call=skip_call)
end

function df_walk_rec(f, e, f_args...; skip=Vector{Symbol}(), skip_call=false)
    if !(e isa Expr) || e.head ∈ skip
        return f(e, f_args...)
    end
    start = 1
    # skip walking on function names
    if skip_call && isexpr(e, :call)
        start = 2
    end

    e.args[start:end] = (@view e.args[start:end]) .|> x ->
        df_walk(f, x, f_args...; skip=skip, skip_call=skip_call)
    return f(e, f_args...)
end



## Breadth First Walk on expressions

"""
Breadth First Walk (Tree Prewalk) on expressions mutates expression in-place.
"""
function bf_walk!(f, e, f_args...; skip=Vector{Symbol}(), skip_call=false)
    if !(e isa Expr) || e.head ∈ skip
        return f(e, f_args...)
    end
    e = f(e, f_args...)
    if !(e isa Expr) return e end
    start = 1
    # skip walking on function names
    if skip_call && isexpr(e, :call)
        start = 2
    end
    e.args[start:end] = e.args[start:end] .|> x ->
        bf_walk!(f, x, f_args...; skip=skip, skip_call=skip_call)
    return e
end


"""
Breadth First Walk (Tree Prewalk) on expressions. Does not mutate expressions.
"""
function bf_walk(f, e, f_args...; skip=Vector{Symbol}(), skip_call=false)
    if !(e isa Expr) || e.head ∈ skip
        return f(e, f_args...)
    end
    ne = copy(e)
    ne = f(e, f_args...)
    if !(ne isa Expr) return ne end
    start = 1
    # skip walking on function names
    if skip_call && isexpr(ne, :call)
        start = 2
    end
    ne.args[start:end] = ne.args[start:end] .|> x ->
        bf_walk(f, x, f_args...; skip=skip, skip_call=skip_call)
    return ne
end
