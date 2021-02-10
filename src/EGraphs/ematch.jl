# https://www.philipzucker.com/egraph-2/
# https://github.com/philzook58/EGraphs.jl/blob/main/src/matcher.jl
# https://www.hpl.hp.com/techreports/2003/HPL-2003-148.pdf
# TODO support destructuring and type assertions

# TODO ematching seems to be faster without spawning tasks

# using StaticArrays

const Sub = Base.ImmutableDict{Any, EClass}

function ematchlist(e::EGraph, t::Vector{Any}, v::Vector{Int64}, sub::Sub)::Vector{Sub}
    # Channel(;spawn=true) do c
    # Channel() do c
    c = Vector{Sub}()

    if length(t) != length(v) || length(t) == 0 || length(v) == 0
        push!(c, sub)
    else
        for sub1 in ematch(e, t[1], v[1], sub)
            for sub2 in ematchlist(e, t[2:end], v[2:end], sub1)
                push!(c, sub2)
            end
        end
    end
    return c
    # end
end

# sub should be a map from pattern variables to Id
function ematch(e::EGraph, t::Symbol, v::Int64, sub::Sub)::Vector{Sub}
    # Channel(;spawn=true) do c
    # Channel() do c

    if haskey(sub, t)
        return find(e, sub[t]) == find(e, v) ? [sub] : []
    else
        return [ Base.ImmutableDict(sub, t => EClass(find(e, v)))]
    end
    # end
end

# function ematch(e::EGraph, t::QuoteNode, v::Int64, sub::Sub)::Vector{Sub}
#     c = Vector{Sub}()
#     for n in e.M[find(e,v)]
#         union!(c, ematchlist(e, t.args[start:end], n.args[start:end] .|> x -> x.id, sub))
#     end
#     return c
# # end
#
function ematch(e::EGraph, t, v::Int64, sub::Sub)::Vector{Sub}
    c = Vector{Sub}()
    id = find(e,v)
    for n in e.M[id]
        if t == n
            if haskey(sub, t)
                union!(c, find(e, sub[t]) == id ? [sub] : [])
            else
                union!(c, [ Base.ImmutableDict(sub, t => EClass(id))])
            end
            # union!(c, ematchlist(e, t.args[start:end], n.args[start:end] .|> x -> x.id, sub))
        end
    end
    return c
end

function ematch(e::EGraph, t::QuoteNode, v::Int64, sub::Sub)::Vector{Sub}
    c = Vector{Sub}()
    id = find(e,v)
    for n in e.M[id]
        if t.value == n
            if haskey(sub, t)
                union!(c, find(e, sub[t]) == id ? [sub] : [])
            else
                union!(c, [ Base.ImmutableDict(sub, t => EClass(id))])
            end
            # union!(c, ematchlist(e, t.args[start:end], n.args[start:end] .|> x -> x.id, sub))
        end
    end
    return c
end

function ematch(e::EGraph, t::Expr, v::Int64, sub::Sub)::Vector{Sub}
    # Channel(;spawn=true) do c
    # Channel() do c

    c = Vector{Sub}()

    for n in e.M[find(e,v)]
        if isexpr(t, :ematch_tassert)
            !(typeof(n) <: t.args[2]) && continue
            # println(Symbol(typeof(n)), " is a ", t.args[2])
            union!(c, ematch(e, t.args[1], v, sub))
            continue
        end

        (!(n isa Expr) || n.head != t.head) && continue
        start = 1
        if n.head == :call
            n.args[1] != t.args[1] && continue
            start = 2
        end

        union!(c, ematchlist(e, t.args[start:end], n.args[start:end] .|> x -> x.id, sub))
    end
    return c
end


inst(var, G::EGraph, sub::Sub) = haskey(sub, var) ? sub[var] : add!(G, var)

inst(p::Expr, G::EGraph, sub::Sub) = add!(G, p)

function instantiate(G::EGraph, p, sub::Sub; skip_assert=false)
    # remove type assertions
    if skip_assert
        p = df_walk( x -> (isexpr(x, :ematch_tassert) ? x.args[1] : x), p; skip_call=true )
    end

    df_walk(inst, p, G, sub; skip_call=true)
end
