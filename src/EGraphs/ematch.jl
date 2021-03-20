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
const SubBuf = Vector{Sub}

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
function ematchlist(e::EGraph, t::AbstractVector{Any}, v::AbstractVector{Int64}, sub::Sub; buf=SubBuf())::SubBuf
    if length(t) != length(v) || length(t) == 0 || length(v) == 0
        push!(buf, sub)
    else
        for sub1 in ematchstep(e, t[1], v[1], sub)
            ematchlist(e, (@view t[2:end]), (@view v[2:end]), sub1; buf=buf)
        end
    end
    return buf
end

# Tries to match on a pattern variable
function ematchstep(g::EGraph, t::Symbol, v::Int64, sub::Sub; lit=nothing, buf=SubBuf())::SubBuf
    if haskey(sub, t)
        if find(g, first(sub[t])) == find(g, v)
            push!(buf, sub)
        end
    else
        push!(buf, Base.ImmutableDict(sub, t => (geteclass(g, find(g, v)), lit)))
    end
    return buf
end

# Tries to match on literals
function ematchstep(g::EGraph, t, v::Int64, sub::Sub; lit=nothing, buf=SubBuf())::SubBuf
    ec = geteclass(g, v)
    for n in ec
        if (t isa QuoteNode ? t.value : t) == n.head
            if haskey(sub, t)
                if find(g, first(sub[t])) == ec.id
                    push!(buf, sub)
                end
            else
                push!(buf, Base.ImmutableDict(sub, t => (ec, n.head)))
            end
        end
    end
    return buf
end

# tries to match on composite expressions
function ematchstep(g::EGraph, t::Expr, v::Int64, sub::Sub; lit=nothing, buf=SubBuf())::SubBuf
    ec = geteclass(g, v)
    for n in ec
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

            !(typeof(n.head) <: typ) && continue
            ematchstep(g, t.args[1], v, sub; lit=n.head, buf=buf)
            continue
        end

        # otherwise ematch on an expr
        (ariety(n) > 0) && n.head == gethead(t) && length(getargs(t)) == length(n.args) || continue
         ematchlist(g, getargs(t), n.args, sub; buf=buf)
    end
    return buf
end

const EMPTY_DICT = Sub()

function ematch(g::EGraph, pat, id::Int64)
    buf = SubBuf()
    ematchstep(g, pat, id, EMPTY_DICT; buf=buf)
    return buf
end
