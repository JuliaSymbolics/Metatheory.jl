using Metatheory, Metatheory.EGraphs
using Test

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
            println("$(n.proof_rules) ⩜ $(n.proof_src) ⩜ $(n.proof_trg)")
        end 
    end

    for i in 1:n
        node = nodes[i]
        if haskey(g.memo, node)
            # TODO really override the proof step here?
            eclass = geteclass(g, g.memo[node])
            for nn in eclass
                if node == nn
                    println("$(node.proof_rules) ⩜ $(node.proof_src) ⩜ $(node.proof_trg)")
                    println("$(nn.proof_rules) ⩜ $(nn.proof_src) ⩜ $(nn.proof_trg)")
                    println("$node == $nn")
                    nodes[i] = nn
                end
            end 
        end
    end
    println("========================================")
    for i in 1:n 
        nn = nodes[i]
        println("$(nn.proof_rules) ⩜ $(nn.proof_src) ⩜ $(nn.proof_trg)")
    end
    println("========================================")
    proof_bfs(nodes[1], nodes[2])
end

mutable struct ProofNode
    state::ENode
    cost::Number
    parent::Union{Nothing, ProofNode}
end


# TODO go through each path in the proof. do a BFS?
using DataStructures
function proof_bfs(src::ENode, trg::ENode)
    root = ProofNode(src, 0, nothing)
    frontier = ProofNode[]
    explored = Set{ENode}()
    push!(frontier, root)
    while !isempty(frontier)
        node = popfirst!(frontier)
        println("exploring $node")
        push!(explored, node.state)
        # todo take rules in account
        for child_enode in node.state.proof_trg
            child = ProofNode(child_enode, node.cost+1, node)
            if child_enode ∉ explored && child ∉ frontier
                # goal test
                if child_enode == trg
                    return child 
                end
                push!(frontier, child)
            end
        end
    end
    error("proof not found!")
end


t = @theory begin 
    a * b == b * a 
    a * 2 == a + a
end


g = EGraph()
addexpr!(g, :(2 * a))
addexpr!(g, :(a + a))
saturate!(g, t)
prove(g, t, :(2 * a), :(a + a))  

prove(EGraph(), t, :(2 * x), :(x + x))

include("../logic/prop_logic_theory.jl")

