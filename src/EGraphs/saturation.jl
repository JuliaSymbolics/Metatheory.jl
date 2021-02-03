

function eqsat_step!(G::EGraph, theory::Vector{Rule}; scheduler=SimpleScheduler())
    matches = Set()
    EMPTY_DICT = Base.ImmutableDict{Any, EClass}()

    readstep(scheduler)

    for rule ∈ theory
        # don't apply banned rules
        shouldskip(scheduler, rule) && continue


        rule.mode != :rewrite && error("unsupported rule mode")
        for id ∈ collect(keys(G.M))
            # println(rule.right)
            for sub in ematch(G, rule.left, id, EMPTY_DICT)
                # display(sub); println()
                !isempty(sub) && push!(matches, (rule, sub, id))
            end
        end
    end

    # @info "write phase"
    for (rule, sub, id) ∈ matches
        writestep(scheduler, rule)

        l = instantiate(G,rule.left,sub)
        r = instantiate(G,rule.right,sub)
        merge!(G,l.id,r.id)
    end

    # display(G.parents); println()
    # display(G.M); println()
    saturated = isempty(G.dirty)
    rebuild!(G)
    return saturated, G
end

# TODO plot how egraph shrinks and grows during saturation
function saturate!(G::EGraph, theory::Vector{Rule};
    timeout=3000, stopwhen=(()->false), sizeout=0, scheduler=BackoffScheduler)

    curr_iter = 0

    # init scheduler
    sched = scheduler(G, theory)

    while true
        # @info curr_iter
        curr_iter+=1
        saturated, G = eqsat_step!(G, theory; scheduler=sched)

        cansaturate(sched) && saturated && (@info "E-GRAPH SATURATED"; break)
        curr_iter >= timeout && (@info "E-GRAPH TIMEOUT"; break)
        sizeout > 0 && length(G.U) > sizeout && (@info "E-GRAPH SIZEOUT"; break)
        stopwhen() && (@info "Halting requirement satisfied"; break)
    end
    return G
end

## Experiments
## TODO finish

# count all possible equal expressions to some eclass
function countexprs(G::EGraph, a::Int64)
    c = length(G.M[a])
    for n ∈ G.M[a]
        if n isa Expr # is enode
            start = isexpr(n, :call) ? 2 : 1
            println(start)
            println(n.args[start:end])
            subcounts = [countexprs(G, x.id) for x ∈ n.args[start:end]]
            for i ∈ subcounts
                println(:wooo, i)
                c *= i
            end
        end
    end
    return c
end

## Simple Extraction


# computes the cost of a constant
astsize(G::EGraph, n) = 1.0

# computes the weight of a function call
function astsize(G::EGraph, n::Expr)
    @assert isenode(n)
    start = isexpr(n, :call) ? 2 : 1
    # if statements about the called function can go here
    length(e.args[start:end])
end

function getbest(G::EGraph, costs::Dict{Int64, Vector{Tuple{Any, Float64}}}, root::Int64)
    # computed costs of equivalent nodes, weighted sum
    ccosts = []
    for n ∈ G.M[root]

    end
end

function extract(G::EGraph, cost::Function)
    costs = Dict{Int64, Vector{Float64}}()

    # compute costs with weights
    for (id, cls) ∈ G.M
        costs[id] = cls .|> cost
    end

    # extract best
    getbest(G, costs, root)
end
