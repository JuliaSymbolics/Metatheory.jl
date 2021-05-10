using Metatheory, Metatheory.EGraphs
using Test

t = @theory begin 
    a * b == b * a 
    a * 2 == a + a
end

function prove(g::EGraph, t::Vector{<:Rule}, exprs...;
    mod=@__MODULE__, params=SaturationParams())
    @info "Checking equality for " exprs
    n = length(exprs)
    if n == 1; return true end
    # rebuild!(G)

    ids = Vector{EClassId}(undef, n)
    nodes = Vector{ENode}(undef, n)
    for i ∈ 1:n
        ec, node = addexpr!(g, exprs[i])
        ids[i] = ec.id
        nodes[i] = node
    end

    goal = EqualityGoal(collect(exprs), ids)
    
    # params.goal = goal
    report = saturate!(g, t, params; mod=mod)

    display(g.classes); println()
    if !(report.reason isa EGraphs.Saturated) && !reached(g, goal)
        return missing # failed to prove
    end

    @show reached(g, goal)

    for (id, ec) in g.classes 
        for n in ec 
            println(id => n)
            println(n.proof)
        end 
    end

    for i in 1:n
        node = nodes[i]
        if haskey(g.memo, node)
            # TODO really override the proof step here?
            eclass = geteclass(g, g.memo[node])
            for nn in eclass
                if node == nn
                    println(node.proof)
                    println(nn.proof)
                    println("$node == $nn")
                    nodes[i] = nn
                end
            end 
        end
    end
    println("========================================")
    for i in 1:n 
        println(nodes[i].proof)
    end
    println("========================================")

    src = nodes[2]
    trg = nothing
    hist = ENode[]
    # TODO save the proof in a verifiable file !!
    while src ∉ hist && trg ∉ hist
        push!(hist, src)
        @assert !isnothing(src.proof)
        rule = src.proof.rule
        trg = src.proof.sub.sourcenode
        if trg ∈ hist 
            break 
        end
        l = EGraphs.extractnode(g, src, a -> EGraphs.rec_extract(g, ExtractionAnalysis{astsize}, a))
        r = EGraphs.extractnode(g, trg, a -> EGraphs.rec_extract(g, ExtractionAnalysis{astsize}, a))


        println("since $rule then")
        println("$l == $r")
        src = trg 
    end
end


g = EGraph()
addexpr!(g, :(2 * a))
addexpr!(g, :(a + a))
saturate!(g, t)
prove(g, t, :(2 * a), :(a + a))  

prove(EGraph(), t, :(2 * x), :(x + x))