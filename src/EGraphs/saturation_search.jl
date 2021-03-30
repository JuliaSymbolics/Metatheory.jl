const Match = Tuple{Rule,Union{Nothing,Pattern},Sub,Int64}
const MatchesBuf = Vector{Match}

function cached_ids(g::EGraph, p::Pattern)# ::Vector{Int64}
    keys(g.classes)
end

# FIXME 
function cached_ids(g::EGraph, p::PatTerm)
    # println("pattern $p, $(p.head)")
    # println("all ids")
    # keys(g.classes) |> println
    # println("cached symbols")
    # cached = get(g.symcache, p.head, Set{Int64}())
    # println("symbols where $(p.head) appears")
    # appears = Set{Int64}() 
    # for (id, class) ∈ g.classes 
    #     for n ∈ class 
    #         if n.head == p.head
    #             push!(appears, id) 
    #         end
    #     end
    # end
    # # println(appears)
    # if !(cached == appears)
    #     @show cached 
    #     @show appears
    # end

    keys(g.classes)
    # cached
    # get(g.symcache, p.head, [])
end

# function cached_ids(g::EGraph, p::PatLiteral)
#     get(g.symcache, p.val, [])
# end

function search_rule!(g::EGraph, r::SymbolicRule, id::Int64, 
    matches::MatchesBuf, mlock::ReentrantLock)
    for sub in ematch(g, r.left, id)
        lock(mlock) do
            push!(matches, (r, r.right, sub, id))
        end
    end
end

function search_rule!(g::EGraph, r::DynamicRule, id::Int64, 
    matches::MatchesBuf, mlock::ReentrantLock)
    for sub in ematch(g, r.left, id)
        lock(mlock) do
            push!(matches, (r, nothing, sub, id))
        end
    end
end

function search_rule!(g::EGraph, r::BidirRule, id::Int64, 
    matches::MatchesBuf, mlock::ReentrantLock)
    for sub in ematch(g, r.left, id)
        lock(mlock) do
            push!(matches, (r, r.right, sub, id))
        end
    end
    for sub in ematch(g, r.right, id)
        lock(mlock) do
            push!(matches, (r, r.left, sub, id))
        end
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

function search_rule!(g::EGraph, r::MultiPatRewriteRule,
    id::Int64, matches::MatchesBuf, mlock::ReentrantLock)
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
        lock(mlock) do 
            push!(matches, (r, r.right, sub, id))
        end
    end
end


function eqsat_search_threaded!(egraph::EGraph, theory::Vector{<:Rule},
        scheduler::AbstractScheduler)::MatchesBuf
    matches = MatchesBuf()
    mlock = ReentrantLock()

    inequalities = filter(theory) do rule 
        rule isa UnequalRule
    end
    # never skip contradiction checks
    Threads.@threads for rule ∈ inequalities
        ids = cached_ids(egraph, rule.left)

        for id ∈ ids
            search_rule!(egraph, rule, id, matches, mlock)
        end
    end

    other_rules = filter(theory) do rule 
        !(rule isa UnequalRule)
    end
    Threads.@threads for rule ∈ other_rules
        # don't apply banned rules
        if shouldskip(scheduler, rule)
            # println("skipping banned rule $rule")
            continue
        end

        ids = cached_ids(egraph, rule.left)

        for id ∈ ids
            search_rule!(egraph, rule, id, matches, mlock)
        end
    end
    return matches
end


function eqsat_search!(egraph::EGraph, theory::Vector{<:Rule},
    scheduler::AbstractScheduler)::MatchesBuf
    matches = MatchesBuf()
    mlock = ReentrantLock()

    inequalities = filter(theory) do rule 
        rule isa UnequalRule
    end
# never skip contradiction checks
    for rule ∈ inequalities
        ids = cached_ids(egraph, rule.left)

        for id ∈ ids
            search_rule!(egraph, rule, id, matches, mlock)
        end
    end

    other_rules = filter(theory) do rule 
        !(rule isa UnequalRule)
    end
    for rule ∈ other_rules
    # don't apply banned rules
        if shouldskip(scheduler, rule)
        # println("skipping banned rule $rule")
            continue
        end

        ids = cached_ids(egraph, rule.left)

        for id ∈ ids
            search_rule!(egraph, rule, id, matches, mlock)
        end
    end
    return matches
end
