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
# function ematchlist(e::EGraph, t::AbstractVector{Pattern}, v::AbstractVector{Int64}, sub::Sub, buf::SubBuf)::SubBuf
#     lt = length(t)
#     lv = length(v)

#     !(lt == lv) && (return buf)

#     # currbuf = buf
#     currbuf = [sub]

#     j = 1
#     for i ∈ 1:lt
#         # newbuf = SubBuf()
#         until = length(currbuf)
#         while j <= until
#             currsub = currbuf[j]
#             ematchstep(e, t[i], v[i], currsub, currbuf)
#             j+=1
#         end
#     end

#     # println(j)
#     # println(currbuf[last_j+1:end])
#     # println(currbuf[j:end])

#     for sub1 ∈ (@view currbuf[j:end]) 
#         push!(buf, sub1)
#     end
#     return buf
# end

function ematchlist(e::EGraph, t::AbstractVector{Pattern}, v::AbstractVector{Int64}, sub, buf::SubBuf)
    lt = length(t)
    lv = length(v)

    lt != lv && (return false)
    if lt == 0 || lv == 0
        push!(buf, sub)
        return 1
    end 

    lb = length(buf)
    # buf1 = SubBuf()
    
    count1 = ematchstep(e, t[1], v[1], sub, buf)
    count1 == 0 && (return 0)
    
    count2 = 0
    for i ∈ (1:count1)
        sub1 = popat!(buf, lb+1)
        count2 += ematchlist(e, (@view t[2:end]), (@view v[2:end]), sub1, buf)
    end
    return count2
end

# Tries to match on a pattern variable
function ematchstep(g::EGraph, t::PatVar, v::Int64, sub, buf::SubBuf)
    if haseclassid(sub, t)
        if find(g, geteclassid(sub, t)) == find(g, v)
            push!(buf, sub)
            return 1 
        end
        return 0
    else
        # nsub = seteclass(sub, t, geteclass(g, v))
        nsub = seteclassid(sub, t, find(g, v))
        push!(buf, nsub)
        return 1
    end
    return 0
end

# Tries to match on literals
function ematchstep(g::EGraph, t::PatLiteral, v::Int64, sub, buf::SubBuf)
    ec = geteclass(g, v)
    # if hascachedpat(sub, t, v)
    #     push!(buf, sub)
    #     return 1 
    # end
    for n in ec
        if arity(n) == 0 && t.val == n.head
            # addcachedpat(sub, t, ec.id)
            push!(buf, sub)
            return 1
        end
    end
    return 0
end


# tries to match on type assertions
function ematchstep(g::EGraph, t::PatTypeAssertion, v::Int64, sub, buf::SubBuf)
    ec = geteclass(g, v)
    nnodes = length(ec.nodes)

    # if hascachedpat(sub, t, ec.id)
    #     println("SAVED!")
    #     return true 
    # end

    count = 0

    for i in 1:nnodes
        n = ec.nodes[i]
        if arity(n) == 0
            !(typeof(n.head) <: t.type) && continue
            nsub = setliteral(sub, t.var, i)
            count += ematchstep(g, t.var, v, nsub, buf)
            continue
        end
    end
    return count
end

# PATEQUIV mechanism
function ematchstep(g::EGraph, t::PatEquiv, v::Int64, sub, buf::SubBuf)
    # if hascachedpat(sub, t, v)
    #     push!(buf, sub)
    #     return 1 
    # end
    buf1 = SubBuf()
    buf2 = SubBuf()

    count1 = ematchstep(g, t.left, v, sub, buf1)

    count2 = 0
    for sub1 ∈ buf1
        count2 += ematchstep(g, t.right, v, sub1, buf2)
    end

    if count1 > 0 && count2 > 0
        # addcachedpat(sub, t, v)
        count = 0

        cbuf = vcat(buf1, buf2)
        for sub ∈ cbuf
            push!(buf, sub)
            count += 1
        end
        return count
    end
    return 0
end

function ematchstep(g::EGraph, t::PatTerm, v::Int64, sub, buf::SubBuf)
    ec = geteclass(g, v)
    # if hascachedpat(sub, t, ec.id)
    #     # println("SAVED! $t")
    #     return 0
    # end

    count = 0
    for n in ec
        (arity(n) > 0) && n.head == t.head && arity(t) == arity(n) || continue
        
        # Filter out to save unnecessary calls 
        ok = true
        for i ∈ 1:arity(n)
            fpat = t.args[i]
            ec = geteclass(g, n.args[i])
            if fpat isa PatTerm
                ok = ok && (fpat.head ∈ funs(ec))
            elseif fpat isa PatLiteral
                ok = ok && (fpat.val ∈ funs(ec))
            end
        end

        if !ok 
            # println("saved time")
            continue
        end
        sub = settermtype(sub, t.head, enodetype(n), getmetadata(n))
        count += ematchlist(g, t.args, n.args, sub, buf) 
    end
    
    # if count > 0
    #     addcachedpat(sub, t, ec.id)
    # end

    return count
end

function ematchstep(g::EGraph, t::PatAllTerm, v::Int64, sub, buf::SubBuf)
    ec = geteclass(g, v)
    # if hascachedpat(sub, t, ec.id)
    #     # println("SAVED!")
    #     return true 
    # end

    count = 0
    for n in ec
        (arity(n) > 0) && arity(t) == arity(n) || continue
        # println(n)
        nsub = settermtype(sub, t.head, enodetype(n), getmetadata(n))
        if haseclassid(sub, t.head)
            if find(g, geteclassid(sub, t.head)) != find(g, v)
                continue
            end
        else
            nsub = seteclassid(sub, t.head, find(g, v))
        end

        # Filter out to save unnecessary calls 
        ok = true
        for i ∈ 1:arity(n)
            fpat = t.args[i]
            ec = geteclass(g, n.args[i])
            if fpat isa PatTerm
                ok = ok && (fpat.head ∈ funs(ec))
            elseif fpat isa PatLiteral
                ok = ok && (fpat.val ∈ funs(ec))
            end
        end

        if !ok 
            # println("saved time")
            continue
        end

        count += ematchlist(g, t.args, n.args, nsub, buf)
    end

    # if ok 
    #     addcachedpat(sub, t, ec.id)
    # end
    return count
end

function ematch(g::EGraph, pat::Pattern, id::Int64, sub=Sub(), buf=SubBuf())
    # println(pat)
    # sub = copy(sub)
    ematchstep(g, pat, id, sub, buf)
    # @show pat
    # println.(buf)
    return buf
end
