using Metatheory, Metatheory.EGraphs
using Test

dbgproof(n::ENode) = println("$(n.proof_src) ⩜ $(n.proof_trg)")

function prove(g::EGraph, t::Vector{<:Rule}, exprs...;
    mod=@__MODULE__, params=SaturationParams())
    # @info "Checking equality for " exprs
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

    # display(g.classes); println()
    if !(report.reason isa EGraphs.Saturated) && !reached(g, goal)
        return missing # failed to prove
    end

    # @show reached(g, goal)

    for (id, ec) in g.classes 
        for n in ec 
            # println(id => n)
            # dbgproof(n)
        end 
    end

    for i in 1:n
        node = nodes[i]
        if haskey(g.memo, node)
            # TODO really override the proof step here?
            eclass = geteclass(g, g.memo[node])
            for nn in eclass
                if node == nn
                    # dbgproof(node)
                    # dbgproof(nn)
                    # println("$node == $nn")
                    nodes[i] = nn
                end
            end 
        end
    end
    # println("========================================")
    # for i in 1:n 
    #     nn = nodes[i]
    #     dbgproof(nn)
    # end
    # println("========================================")
    @show reached(g, goal)
    proof_bfs(g, nodes[1], nodes[2])
end

mutable struct ProofNode
    state::ENode
    why::Union{Nothing,Rule}
    when::Int
    cost::Number
    parent::Union{Nothing, ProofNode}
end

struct Proof 
    g::EGraph
    head::ProofNode
end

"""
A closured cost function that considers the age of the enode and the ast size.
"""
function oldestatage(age::Int)
    return (n::ENode, g::EGraph, an::Type{<:AbstractAnalysis}) -> begin 
        # cost = 0
        # println("current age is $age")
        # println("enode $n age is $(n.age)")
        # cost = n.age - age
        cost = n.age - age
        # println("cost is $cost")
        return cost
    end
end



function oldest_node_extract(g::EGraph, n::ENode, age::Int)
    costfun = oldestatage(age)
    ex = EGraphs.extractnode(g, n, ExtractionAnalysis{costfun})
    # println("extracted $ex aged $(n.age) at age $age")
    return ex
end

function Base.show(io::IO, mime::MIME"text/plain", proof::Proof)
    lines = []
    curr = proof.head
    while !isnothing(curr.parent)
        ex = oldest_node_extract(proof.g, curr.state, curr.when)
        pushfirst!(lines, "$ex")
        pushfirst!(lines, "from $(repr("text/plain", curr.why))")
        curr = curr.parent
    end 
    ex = oldest_node_extract(proof.g, curr.state, curr.when)
    pushfirst!(lines, "given $ex")

    for line in lines 
        println(io, line)
    end
end

# TODO go through each path in the proof. do a BFS?
using DataStructures
function proof_bfs(g::EGraph, src::ENode, trg::ENode)
    root = ProofNode(src, nothing, src.age, 0, nothing)
    if src == trg
        return Proof(g, root) 
    end
    frontier = ProofNode[]
    explored = Set{ENode}()
    push!(frontier, root)
    while !isempty(frontier)
        node = popfirst!(frontier)
        # println("exploring $node")
        push!(explored, node.state)
        # todo take rules in account
        for (rule, child_enode, age) in unique(node.state.proof_trg) #∪ node.state.proof_src
            child = ProofNode(child_enode, rule, age, node.cost+1, node)
            if child_enode ∉ explored && child ∉ frontier
                # goal test
                if child_enode == trg
                    return Proof(g, child) 
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


# g = EGraph()
# addexpr!(g, :(2 * a))
# addexpr!(g, :(a + a))
# saturate!(g, t)
# proof = prove(g, t, :(2 * a), :(a + a))  

# Base.print(proof)

prove(EGraph(), t, :(2 * x), :(x + x))

include("../logic/prop_logic_theory.jl")

@metatheory_init ()

ex = :((x => (y => z)) => ((x => y) => (x => z)))
proof = prove(EGraph(), t, ex, true)


proof = prove(EGraph(), t, :((x => (x ∨ x))), :((¬(x) ∧ y) => y))

# TODO introduce a mechanism of enode age and egraph age to be able to extract 
# precisely which enode was there at that moment
# to be printed, if rule was applied at time `t`, then extract the enodes that was 
# applied earliest but before (or after???) `t`  
ex = :(((x ∨ y) ∨ ¬(z ∧ a)) ∨ a)
proof = prove(EGraph(), t, ex, true)

Metatheory.options.verbose = false




# chat with oliver 
# introduce a new type of enode at the proof generation stage 
# set of unknown variables


# keep proof at the expr level 
# do not store src and trg in enode 
# store holes 
# 
# keep another unionfind for the same holes