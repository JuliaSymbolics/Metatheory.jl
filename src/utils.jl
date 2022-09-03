using Base:ImmutableDict

function binarize(e::T) where {T}
    !istree(e) && return e
    head = exprhead(e)
    if head == :call
        op = operation(e)
        args = arguments(e)
        meta = metadata(e)
        if op ∈ binarize_ops && arity(e) > 2
            return foldl((x,y) -> similarterm(T, op, [x,y], symtype(e); metadata=meta, exprhead=head), args)
        end
    end
    return e
end 

const binarize_ops = [:(+), :(*), (+), (*)]

function cleanast(e::Expr)
    # TODO better line removal 
    if isexpr(e, :block)
        return Expr(e.head, filter(x -> !(x isa LineNumberNode), e.args)...)
    end

    # Binarize
    if isexpr(e, :call)
        op = e.args[1]
        if op ∈ binarize_ops && length(e.args) > 3
            return foldl((x,y) -> Expr(:call, op, x, y), @view e.args[2:end])
        end
    end
    return e
end

# Linked List interface
@inline assoc(d::ImmutableDict, k, v) = ImmutableDict(d, k => v)

struct LL{V}
    v::V
    i::Int
end

islist(x) = istree(x) || !isempty(x)

Base.empty(l::LL) = empty(l.v)
Base.isempty(l::LL) = l.i > length(l.v)

Base.length(l::LL) = length(l.v) - l.i + 1
@inline car(l::LL) = l.v[l.i]
@inline cdr(l::LL) = isempty(l) ? empty(l) : LL(l.v, l.i + 1)

# Base.length(t::Term) = length(arguments(t)) + 1 # PIRACY
# Base.isempty(t::Term) = false
# @inline car(t::Term) = operation(t)
# @inline cdr(t::Term) = arguments(t)

@inline car(v) = istree(v) ? operation(v) : first(v)
@inline function cdr(v)
    if istree(v)
        arguments(v)
    else
        islist(v) ? LL(v, 2) : error("asked cdr of empty")
    end
end

@inline take_n(ll::LL, n) = isempty(ll) || n == 0 ? empty(ll) : @views ll.v[ll.i:n + ll.i - 1] # @views handles Tuple
@inline take_n(ll, n) = @views ll[1:n]

@inline function drop_n(ll, n)
    if n === 0
        return ll
    else
        istree(ll) ? drop_n(arguments(ll), n - 1) : drop_n(cdr(ll), n - 1)
    end
end
@inline drop_n(ll::Union{Tuple,AbstractArray}, n) = drop_n(LL(ll, 1), n)
@inline drop_n(ll::LL, n) = LL(ll.v, ll.i + n)
            


isliteral(::Type{T}) where {T} = x -> x isa T
is_literal_number(x) = isliteral(Number)(x)

# are there nested ⋆ terms?
function isnotflat(⋆)
    function (x)
    args = arguments(x)
        for t in args
            if istree(t) && operation(t) === (⋆)
        return true
            end
        end
return false
    end
end

function hasrepeats(x)
        length(x) <= 1 && return false
    for i = 1:length(x) - 1
        if isequal(x[i], x[i + 1])
                return true
        end
        end
        return false
end

function merge_repeats(merge, xs)
    length(xs) <= 1 && return false
    merged = Any[]
    i = 1

            while i <= length(xs)
        l = 1
        for j = i + 1:length(xs)
            if isequal(xs[i], xs[j])
        l += 1
            else
                break
end
end
        if l > 1
            push!(merged, merge(xs[i], l))
else
            push!(merged, xs[i])
        end
        i += l
    end
    return merged
end

# Take a struct definition and make it be able to match in `@rule`
macro matchable(expr)
    @assert expr.head == :struct
    name = expr.args[2]
    if name isa Expr && name.head === :curly
        name = name.args[1]
    end
    fields = filter(x -> !(x isa LineNumberNode), expr.args[3].args)
    get_name(s::Symbol) = s
    get_name(e::Expr) = (@assert(e.head == :(::)); e.args[1])
    fields = map(get_name, fields)
    quote
        $expr
        TermInterface.istree(::$name) = true
        TermInterface.istree(::Type{<:$name}) = true
        TermInterface.operation(::$name) = $name
        TermInterface.arguments(x::$name) = getfield.((x,), ($(QuoteNode.(fields)...),))
        TermInterface.arity(x::$name) = $(length(fields))
        Base.length(x::$name) = $(length(fields) + 1)
    end |> esc
end


using TimerOutputs

const being_timed = Ref{Bool}(false)

macro timer(name, expr)
    :(if being_timed[]
            @timeit $(esc(name)) $(esc(expr))
        else
            $(esc(expr))
        end)
end

macro iftimer(expr)
    esc(expr)
end

function timerewrite(f)
    reset_timer!()
    being_timed[] = true
    x = f()
    being_timed[] = false
    print_timer()
    println()
    x
end

"""
    @timerewrite expr

If `expr` calls `simplify` or a `RuleSet` object, track the amount of time
it spent on applying each rule and pretty print the timing.

This uses [TimerOutputs.jl](https://github.com/KristofferC/TimerOutputs.jl).

## Example:

```julia

julia> expr = foldr(*, rand([a,b,c,d], 100))
(a ^ 26) * (b ^ 30) * (c ^ 16) * (d ^ 28)

julia> @timerewrite simplify(expr)
 ────────────────────────────────────────────────────────────────────────────────────────────────
                                                         Time                   Allocations
                                                 ──────────────────────   ───────────────────────
                Tot / % measured:                     340ms / 15.3%           92.2MiB / 10.8%

 Section                                 ncalls     time   %tot     avg     alloc   %tot      avg
 ────────────────────────────────────────────────────────────────────────────────────────────────
 Rule((~y) ^ ~n * ~y => (~y) ^ (~n ...    667   11.1ms  21.3%  16.7μs   2.66MiB  26.8%  4.08KiB
   RHS                                       92    277μs  0.53%  3.01μs   14.4KiB  0.14%     160B
 Rule((~x) ^ ~n * (~x) ^ ~m => (~x)...    575   7.63ms  14.6%  13.3μs   1.83MiB  18.4%  3.26KiB
 (*)(~(~(x::!issortedₑ))) => sort_arg...    831   6.31ms  12.1%  7.59μs    738KiB  7.26%     910B
   RHS                                      164   3.03ms  5.81%  18.5μs    250KiB  2.46%  1.52KiB
   ...
   ...
 ────────────────────────────────────────────────────────────────────────────────────────────────
(a ^ 26) * (b ^ 30) * (c ^ 16) * (d ^ 28)
```
"""
macro timerewrite(expr)
    :(timerewrite(()->$(esc(expr))))
end
