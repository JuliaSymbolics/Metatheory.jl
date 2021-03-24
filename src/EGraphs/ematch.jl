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
function ematchlist(e::EGraph, t::AbstractVector{Pattern}, v::AbstractVector{Int64}, sub::Sub; buf=SubBuf())::SubBuf
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
function ematchstep(g::EGraph, t::PatVar, v::Int64, sub::Sub; lit=nothing, buf=SubBuf())::SubBuf
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
function ematchstep(g::EGraph, t::PatLiteral, v::Int64, sub::Sub; lit=nothing, buf=SubBuf())::SubBuf
    ec = geteclass(g, v)
    for n in ec
        if arity(n) == 0 && t.val == n.head
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


# tries to match on type assertions
function ematchstep(g::EGraph, t::PatTypeAssertion, v::Int64, sub::Sub; lit=nothing, buf=SubBuf())::SubBuf
    ec = geteclass(g, v)
    for n in ec
        if arity(n) == 0
            !(typeof(n.head) <: t.type) && continue
            ematchstep(g, t.var, v, sub; lit=n.head, buf=buf)
            continue
        end
    end
    return buf
end


# tries to match on composite expressions
function ematchstep(g::EGraph, t::PatTerm, v::Int64, sub::Sub; lit=nothing, buf=SubBuf())::SubBuf
    ec = geteclass(g, v)
    for n in ec
        (arity(n) > 0) && n.head == t.head && arity(t) == arity(n) || continue
         ematchlist(g, t.args, n.args, sub; buf=buf)
    end
    return buf
end

const EMPTY_DICT = Sub()

function ematch(g::EGraph, pat::Pattern, id::Int64)
    buf = SubBuf()
    ematchstep(g, pat, id, EMPTY_DICT; buf=buf)
    @show pat
    println.(buf)
    return buf
end
