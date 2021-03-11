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

# https://www.hpl.hp.com/techreports/2003/HPL-2003-148.pdf
# page 48
"""
From [https://www.hpl.hp.com/techreports/2003/HPL-2003-148.pdf](https://www.hpl.hp.com/techreports/2003/HPL-2003-148.pdf)
The iterator `ematchlist` matches a list of terms `t` to a list of E-nodes by first finding
all substitutions that match the first term to the first E-node, and then extending
each such substitution in all possible ways that match the remaining terms to
the remaining E-nodes. The base case of this recursion is the empty list, which
requires no extension to the substitution; the other case relies on Match to find the
substitutions that match the first term to the first E-node.
"""
function ematchlist(e::EGraph, t::Vector{Any}, v::AbstractVector{Int64}, sub::Sub)::Vector{Sub}
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
end

# sub should be a map from pattern variables to Id
function ematch(e::EGraph, t::Symbol, v::Int64, sub::Sub; lit=nothing)::Vector{Sub}
    if haskey(sub, t)
        return find(e, first(sub[t])) == find(e, v) ? [sub] : []
    else
        return [ Base.ImmutableDict(sub, t => (EClass(find(e, v)), lit)) ]
    end
end

function ematch(e::EGraph, t, v::Int64, sub::Sub; lit=nothing)::Vector{Sub}
    c = Vector{Sub}()
    id = find(e,v)
    for n in e.M[id]
        if (t isa QuoteNode ? t.value : t) == n.sym
            if haskey(sub, t)
                union!(c, find(e, first(sub[t])) == id ? [sub] : [])
            else
                union!(c, [ Base.ImmutableDict(sub, t => (EClass(id), n.sym))])
            end
            # union!(c, ematchlist(e, t.args[start:end], n.args[start:end] .|> x -> x.id, sub))
        end
    end
    return c
end


function ematch(e::EGraph, t::Expr, v::Int64, sub::Sub; lit=nothing)::Vector{Sub}
    c = Vector{Sub}()

    for n in e.M[find(e,v)]
        if isexpr(t, :(::)) && ariety(n) == 0
            # right hand of type assertion
            # tr = t.args[2]
            typ = t.args[2]

            # println(n)
            # println(typ, " ", typeof(typ))
            # if tr isa Type
            #     typ = tr
            # elseif tr isa Symbol
            #     if haskey(sub, tr)
            #         typ = sub[tr][2]
            #     else
            #         # add the type to the egraph
            #         type_id = add!(e, typeof(n))
            #         sub =  Base.ImmutableDict(sub, t.args[2] => (type_id, typeof(n)))
            #         typ = typeof(n)
            #         # union!(c, ematch(e, t, v, sub))
            #         # continue
            #     end
            # # elseif isexpr(tr, :curly)
            # # TODO allow for parametric type variables
            # # see https://dl.acm.org/doi/pdf/10.1145/3276483
            # else
            #     error("Unsupported type assertion '", t, "'")
            # end

            !(typeof(n.sym) <: typ) && continue
            union!(c, ematch(e, t.args[1], v, sub; lit=n.sym))
            continue
        end

        # otherwise ematch on an expr
        (!(ariety(n) > 0) || n.sym != getfunsym(t)) && continue
        union!(c, ematchlist(e, getfunargs(t), n.args, sub))
    end
    return c
end
