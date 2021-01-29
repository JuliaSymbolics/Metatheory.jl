## Utility functions

## AST manipulation utility functions

# Remove LineNumberNode from quoted blocks of code
rmlines(e::Expr) = Expr(e.head, filter(!isnothing, map(rmlines, e.args))...)
rmlines(a) = a
rmlines(x::LineNumberNode) = nothing

# useful shortcuts for nested macros
dollar(v) = Expr(:$, v)
block(vs...) = Expr(:block, vs...)
amp(v) = Expr(:&, v)

# meta shortcuts for readability
quot = Meta.quot
isexpr = Meta.isexpr


cleanast(ex) = rmlines(ex) |>
    x -> binarize!(x, :(+)) |>
    x -> binarize!(x, :(*))

## Depth First Walk on expressions

# mutates expression in-place !
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

# returns a new expression
function df_walk(f, e, f_args...; skip=Vector{Symbol}(), skip_call=false)
    if !(e isa Expr) || e.head ∈ skip
        return f(e, f_args...)
    end
    start = 1
    # skip walking on function names
    if skip_call && isexpr(e, :call)
        start = 2
    end

    ne = copy(e)
    ne.args[start:end] = ne.args[start:end] .|> x ->
        df_walk(f, x, f_args...; skip=skip, skip_call=skip_call)
    return f(ne, f_args...)
end



## Breadth First Walk on expressions

# mutates expression in-place !
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


# returns a new expression
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

##

## Iterate a function on a datum until a fixed point is reached where f(x) = x
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
