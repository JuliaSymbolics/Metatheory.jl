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
            println("$n.proof_rules ⩜ $n.proof_src ⩜ $n.proof_trg")
        end 
    end

    for i in 1:n
        node = nodes[i]
        if haskey(g.memo, node)
            # TODO really override the proof step here?
            eclass = geteclass(g, g.memo[node])
            for nn in eclass
                if node == nn
                    println("$n.proof_rules ⩜ $n.proof_src ⩜ $n.proof_trg")
                    println("$nn.proof_rules ⩜ $nn.proof_src ⩜ $nn.proof_trg")
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

    # TODO go through each path in the proof. do a BFS?
end


g = EGraph()
addexpr!(g, :(2 * a))
addexpr!(g, :(a + a))
saturate!(g, t)
prove(g, t, :(2 * a), :(a + a))  

prove(EGraph(), t, :(2 * x), :(x + x))