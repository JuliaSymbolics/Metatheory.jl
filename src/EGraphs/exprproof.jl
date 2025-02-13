export PositionedProof, find_node_proof, detailed_dict


mutable struct PositionedProof
  """
  Positioned proof is a structure that keeps track of where we apply proofs to in larger expressions.
  """
  proof::Vector{ProofNode}
  children::Vector{PositionedProof}
  # TODO: Track what is matched
end

function detailed_dict(pc::ProofConnection, g::EGraph)
  return Dict(
    "next" => to_expr(g, g.nodes[pc.next]), # TODO: node should be unfolded, i.e., subexpressions should be exprs not node ids
    "current" => to_expr(g, g.nodes[pc.current]), # TODO: node should be unfolded, i.e., subexpressions should be exprs not node ids
    "justification" => pc.justification # TODO: Change to the rules name + params
  )
end

function detailed_dict(pn::ProofNode, g::EGraph)
  return Dict(
    "existence_node" => to_expr(g, g.nodes[pn.existence_node]), # TODO: node should be unfolded, i.e., subexpressions should be exprs not node ids
    "parent_connection" => detailed_dict(pn.parent_connection,g),
    "neighbours" => map(x -> detailed_dict(x, g), pn.neighbours)
  )
end

function detailed_dict(pp::PositionedProof, g::EGraph)
  return Dict(
    "proof" => map(x -> detailed_dict(x, g), pp.proof), 
    "children" => map(x -> detailed_dict(x, g), pp.children) 
  )
end

Base.show(io::IO, pp::PositionedProof) = begin
  println(io, "PositionedProof(")
  println(io, "  proof = ", pp.proof)
  println(io, "  children = [")
  for child in pp.children
    show(io, child)
  end
  println(io, "  ]")
  println(io, ")")
end


function find_node_proof(g::EGraph, node1::Id, node2::Id)::Union{Tuple{PositionedProof, PositionedProof}, Nothing}
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



  # Idea: rewrite both sides to "normal forms" and concat
  # TODO: This is definetely suboptimal and should be optimized
  # LCA?
  leader1, nfproof1 = rewrite_to_normal_form(g, node1)
  leader2, nfproof2 = rewrite_to_normal_form(g, node2)
  println("==========")
  println(leader1)
  println(leader2)
  println(g)
  println(nfproof1)
  println(nfproof2)
  if leader1 != leader2
    return nothing
  end
  return (nfproof1, nfproof2)


end

#
function rewrite_to_normal_form(g::EGraph, node::Id)::Tuple{Id,PositionedProof}
  # Start off by rewriting node to leader
  lp = rewrite_to_leader(g.proof, node)
  leader = lp.leader
  leader_proof = lp.proof

  expr = g.nodes[leader]
  proof = PositionedProof(leader_proof, [])
  sizehint!(proof.children, v_arity(expr))
  # Do we want to do this before or after tthe leader proof?
  for child in v_children(expr)
    _, child_proof = rewrite_to_normal_form(g, child)
    push!(proof.children, child_proof)
  end
  return (leader, proof)
end