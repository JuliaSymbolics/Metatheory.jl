# https://www.philipzucker.com/egraph-2/
# https://github.com/philzook58/EGraphs.jl/blob/main/src/matcher.jl
# https://www.hpl.hp.com/techreports/2003/HPL-2003-148.pdf
# TODO support destructuring
# DONE support type assertions

# ematching seems to be faster without spawning tasks

# we keep a pair of EClass, Any in substitutions because
# when evaluating dynamic rules we also want to know
# what was the value of a matched literal
const Sub = Base.ImmutableDict{Any, Tuple{EClass, Any}}

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
function ematch(e::EGraph, t::Symbol, v::Int64, sub::Sub; lit=nothing)::Vector{Sub}
    # Channel(;spawn=true) do c
    # Channel() do c

    if haskey(sub, t)
        return find(e, first(sub[t])) == find(e, v) ? [sub] : []
    else
        return [ Base.ImmutableDict(sub, t => (EClass(find(e, v)), lit)) ]
    end
    # end
end

function ematch(e::EGraph, t, v::Int64, sub::Sub)::Vector{Sub}
    c = Vector{Sub}()
    id = find(e,v)
    for n in e.M[id]
        if (t isa QuoteNode ? t.value : t) == n
            if haskey(sub, t)
                union!(c, find(e, first(sub[t])) == id ? [sub] : [])
            else
                union!(c, [ Base.ImmutableDict(sub, t => (EClass(id), n))])
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
            union!(c, ematch(e, t.args[1], v, sub; lit=n))
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
