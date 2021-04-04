# https://www.philipzucker.com/egraph-2/
# https://github.com/philzook58/EGraphs.jl/blob/main/src/matcher.jl
# https://www.hpl.hp.com/techreports/2003/HPL-2003-148.pdf
# TODO support destructuring

# ematching seems to be faster without spawning tasks

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
function ematchlist(e::EGraph, t::AbstractVector{Pattern}, v::AbstractVector{Int64}, sub::Sub, buf::SubBuf)::SubBuf
    lt = length(t)
    lv = length(v)

    !(lt == lv) && (return buf)

    # currbuf = buf
    currbuf = [sub]

    j = 1
    for i ∈ 1:lt
        # newbuf = SubBuf()
        until = length(currbuf)
        while j <= until
            currsub = currbuf[j]
            ematchstep(e, t[i], v[i], currsub, currbuf)
            j+=1
        end
    end

    # println(j)
    # println(currbuf[last_j+1:end])
    # println(currbuf[j:end])

    for sub1 ∈ (@view currbuf[j:end]) 
        push!(buf, sub1)
    end
    return buf
end

# Tries to match on a pattern variable
function ematchstep(g::EGraph, t::PatVar, v::Int64, sub::Sub, buf::SubBuf)::SubBuf
    if haseclassid(sub, t)
        if find(g, geteclassid(sub, t)) == find(g, v)
            push!(buf, sub)
        end
    else
        # nsub = seteclass(sub, t, geteclass(g, v))
        nsub = copy(sub)
        seteclassid!(nsub, t, find(g, v))
        push!(buf, nsub)
    end
    return buf
end

# Tries to match on literals
function ematchstep(g::EGraph, t::PatLiteral, v::Int64, sub::Sub, buf::SubBuf)::SubBuf
    ec = geteclass(g, v)
    for n in ec
        if arity(n) == 0 && t.val == n.head
            push!(buf, sub)
            break
        end
    end
    return buf
end


# tries to match on type assertions
function ematchstep(g::EGraph, t::PatTypeAssertion, v::Int64, sub::Sub, buf::SubBuf)::SubBuf
    ec = geteclass(g, v)
    nnodes = length(ec.nodes)
    for i in 1:nnodes
        n = ec.nodes[i]
        if arity(n) == 0
            !(typeof(n.head) <: t.type) && continue
            # nsub = copy(sub)
            nsub = sub
            setliteral!(nsub, t.var, i)
            ematchstep(g, t.var, v, nsub, buf)
            continue
        end
    end
    return buf
end

# PATEQUIV mechanism
function ematchstep(g::EGraph, t::PatEquiv, v::Int64, sub::Sub, buf::SubBuf)::SubBuf
    buf1 = SubBuf()
    buf2 = SubBuf()

    
    for sub1 ∈ ematchstep(g, t.left, v, sub, buf1)
        ematchstep(g, t.right, v, sub1, buf2)
    end

    if !isempty(buf1) && !isempty(buf2) 
        for sub ∈ vcat(buf1, buf2)
            push!(buf, sub)
        end
    end
    return buf 
end

function ematchstep(g::EGraph, t::PatTerm, v::Int64, sub::Sub, buf::SubBuf)::SubBuf
    ec = geteclass(g, v)
    for n in ec
        (arity(n) > 0) && n.head == t.head && arity(t) == arity(n) || continue
        nsub = settermtype(sub, t.head, enodetype(n), getmetadata(n))
        ematchlist(g, t.args, n.args, nsub, buf)
    end
    return buf
end

function ematchstep(g::EGraph, t::PatAllTerm, v::Int64, sub::Sub, buf::SubBuf)::SubBuf
    ec = geteclass(g, v)
    for n in ec
        (arity(n) > 0) && arity(t) == arity(n) || continue
        println(n)
        nsub = settermtype(sub, t.head, enodetype(n), getmetadata(n))
        if haseclassid(nsub, t.head)
            if find(g, geteclassid(nsub, t.head)) == find(g, v)
                ematchlist(g, t.args, n.args, nsub, buf)
            end
        else
            nsub = copy(sub) 
            seteclassid!(nsub, t.head, find(g, v))
            ematchlist(g, t.args, n.args, nsub, buf)
        end
    end
    return buf
end

function ematch(g::EGraph, pat::Pattern, id::Int64, sub::Sub, buf=SubBuf())
    # println(pat)
    # sub = copy(sub)
    ematchstep(g, pat, id, sub, buf)
    # @show pat
    # println.(buf)
    return buf
end
