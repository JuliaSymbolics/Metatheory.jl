export PositionedProof, find_node_proof


mutable struct PositionedProof
  """
  Positioned proof is a structure that keeps track of where we apply proofs to in larger expressions.
  """
  proof::Vector{ProofNode}
  children::Vector{PositionedProof}
  # TODO: Track what is matched
end

function find_node_proof(g::EGraph, node1::Id, node2::Id)::PositionedProof
  # Proof  search that can deal with expressions, too.

  # Idea:

  # Walk expr trees

  # For each node:
  #   If has flat proof, proof to leader
  #   Else, recursively unfold 
  
  # If no proof found for subexpr, return nothing

  # Issues: how to relate expressions?
  # Especially if different Size
  # e.g. a*(b+c) = ab+bc (which is different size AST)
  # bigger problem comes when a=z then z*(b+c) = ab+bc

  # So I guess the way we should go about it is go to base terms, rewrite to leader

  flat_proof = find_flat_proof(g.proof, node1, node2)
  # If there is a basic proof, no need to construct something more complicated
  # TODO: Profile if this kills performance
  if length(flat_proof) != 0
    return flat_proof
  end

  # Idea: rewrite both sides to "normal forms" and concat
  # TODO: This is definetely suboptimal and should be optimized
  

  
end

#
function rewrite_to_normal_form(g::EGraph, node::Id)::PositionedProof
    # Start off by rewriting node to leader
    lp = rewrite_to_leader(g.proof, node1)
    leader = lp.leader
    leader_proof = lp.proof
  
    expr = g.nodes[leader]
    proof = PositionedProof(leader_proof, []) 

    for (idx, child) in enumerate(v_children(expr))
      proof.children[idx] = rewrite_to_normal_form(g, child)
    end
    return PositionedProof
end