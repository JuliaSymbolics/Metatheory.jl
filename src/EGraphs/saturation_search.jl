const Match = Tuple{Rule, Union{Nothing, Pattern}, Sub, Int64}
const MatchesBuf = Vector{Match}

function cached_ids(g::EGraph, p::Pattern)#::Vector{Int64}
    keys(g.classes)
end

# FIXME 
function cached_ids(g::EGraph, p::PatTerm)
    # println(p)
    # println(get(g.symcache, p.head, []))
    keys(g.classes)
    # get(g.symcache, p.head, [])
end

# function cached_ids(g::EGraph, p::PatLiteral)
#     get(g.symcache, p.val, [])
# end

function search_rule!(g::EGraph, r::SymbolicRule, id::Int64, matches::MatchesBuf)
    for sub in ematch(g, r.left, id)
        push!(matches, (r, r.right, sub, id))
    end
end

function search_rule!(g::EGraph, r::DynamicRule, id::Int64, matches::MatchesBuf)
    for sub in ematch(g, r.left, id)
        push!(matches, (r, nothing, sub, id))
    end
end

function search_rule!(g::EGraph, r::BidirRule, id::Int64, matches::MatchesBuf)
    for sub in ematch(g, r.left, id)
        push!(matches, (r, r.right, sub, id))
    end
    for sub in ematch(g, r.right, id)
        push!(matches, (r, r.left, sub, id))
    end
end

function Base.show(io::IO, s::Sub)
    print(io, "Sub[")
    kvs = collect(s)
    n = length(kvs)
    for i ∈ 1:n
        print(io, kvs[i][1], " => ", kvs[i][2][1].id)
        if i < n 
            print(io, ",")
        end
    end
    print(io, "]")
end

function search_rule!(g::EGraph, r::MultiPatRewriteRule, id::Int64, matches::MatchesBuf)
    buf = ematch(g, r.left, id)
    if isempty(buf)
        return 
    end
    pats_todo = reverse(copy(r.pats))
    while !isempty(pats_todo)
        pat = pop!(pats_todo)
        # println("====================")
        # @show pat
        ids = cached_ids(g, pat)
        newbuf = SubBuf()
        while !isempty(buf)
            sub = pop!(buf)
            # @show sub
            isempty(sub) && continue
            for i ∈ ids
                ematch(g, pat, i, sub, newbuf)
            end
        end
        buf = copy(newbuf)
    end
    for sub in buf
        # println("FINALLY ", sub, " $id")
        push!(matches, (r, r.right, sub, id))
    end
end


function eqsat_search!(egraph::EGraph, theory::Vector{<:Rule},
        scheduler::AbstractScheduler)::MatchesBuf
    matches=MatchesBuf()
    for rule ∈ theory
        # don't apply banned rules
        if shouldskip(scheduler, rule)
            # println("skipping banned rule $rule")
            continue
        end

        ids = cached_ids(egraph, rule.left)

        for id ∈ ids
            search_rule!(egraph, rule, id, matches)
        end
    end
    return matches
end
