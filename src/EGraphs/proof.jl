export ProofConnection, ProofNode, EGraphProof, find_flat_proof, rewrite_to_leader

mutable struct ProofConnection
  """
  Justification can be 
  - 0 if the connection is justified by congruence 
  - Positive integer is index of the rule in theory, applied left-to-right.
  - Negative integer is same as above, applied right-to-left.
  The absolute value is thus the rule id.
  """
  justification::Int
  # Next is equal to itself on leaves of the proof tree 
  # i.e. only the identity (congruence) is a valid proof 
  next::Id
  current::Id
end

function Base.show(io::IO, p::ProofConnection)
  j = abs(p.justification)
  p.justification == 0 && return print(io, "($(p.current) ≡ $(p.next))")
  p.justification < 0 && return print(io, "($(p.current) <-$j- $(p.next))")
  print(io, "($(p.current) -$j-> $(p.next))")
end


mutable struct ProofNode
  # TODO: Explain
  existence_node::Id
  # TODO is this the parent in the unionfind?
  parent_connection::ProofConnection
  # TODO Always includes parent ??????
  neighbours::Vector{ProofConnection}
end

function Base.show(io::IO, p::ProofNode)
  print(io, "ProofNode(")
  print(io, p.existence_node, ", ")
  print(io, p.parent_connection, ", ")
  print(io, p.neighbours, ")")
end


Base.@kwdef struct EGraphProof
  explain_find::Vector{ProofNode} = ProofNode[]
  uncanon_memo::Dict{VecExpr,Id} = Dict{VecExpr,Id}()
end

# TODO find better name for existence_node and set
function add!(proof::EGraphProof, n::VecExpr, set::Id, existence_node::Id)
  # Insert in the uncanonical memo 
  # TODO explain why
  proof.uncanon_memo[n] = set

  # New proof node does not have any neighbours
  # Parent connection is by congruence, to the same id 
  proof_node = ProofNode(existence_node, ProofConnection(0, set, set), ProofConnection[])
  push!(proof.explain_find, proof_node)
  set
end

# Returns true if it did something 
function make_leader(proof::EGraphProof, node::Id)::Bool
  proof_node = proof.explain_find[node]
  # Next is equal to itself on leaves of the proof tree 
  # i.e. only the identity (congruence) is a valid proof
  # TODO we should change the type 
  next = proof_node.parent_connection.next
  next == node && return false

  make_leader(proof, next)
  # You need to re-fetch it if there's a circular proof? 
  # TODO adrian please expand.
  proof_node = proof.explain_find[node]
  old_parent_connection = proof_node.parent_connection
  # Reverse the justification
  new_parent_connection = ProofConnection(-old_parent_connection.justification, node, old_parent_connection.next)

  proof.explain_find[next].parent_connection = new_parent_connection

  true
end


function Base.union!(proof::EGraphProof, node1::Id, node2::Id, rule_idx::Int)
  # TODO maybe should have extra argument called `rhs_new` in egg that is true when called from 
  # application of rules where the instantiation of the rhs creates new e-classes
  # TODO if new_rhs set_existance_reason of node2 to node1

  # Make node1 the root
  make_leader(proof, node1)

  proof_node1 = proof.explain_find[node1]
  proof_node2 = proof.explain_find[node2]

  proof.explain_find[node1].parent_connection.next = node2

  pconnection = ProofConnection(abs(rule_idx), node2, node1)
  other_pconnection = ProofConnection(-(abs(rule_idx)), node1, node2)


  push!(proof_node1.neighbours, pconnection)
  push!(proof_node2.neighbours, other_pconnection)

  # TODO WAT???
  proof_node1.parent_connection = pconnection
end

@inline isroot(pn::ProofNode) = isroot(pn.parent_connection)
@inline isroot(pc::ProofConnection) = pc.current === pc.next





function find_flat_proof(proof::EGraphProof, node1::Id, node2::Id)::Vector{ProofNode}
  # We're doing a lowest common ancestor search.
  # We cache the IDs we have seen
  seen_set = Set{Id}()
  # Store the nodes seen from node1 and node2 in order
  walk_from1 = ProofNode[]
  walk_from2 = ProofNode[]

  # No existence_node would ever have id 0
  lca = UInt(0)
  curr = proof.explain_find[node1]
  if (node1 == node2)
    return [curr]
  end

  # Walk up to the root
  while true
    push!(seen_set, curr.existence_node)
    isroot(curr) ? break : push!(walk_from1, curr)
    curr = proof.explain_find[curr.parent_connection.next]
  end

  curr = proof.explain_find[node2]
  @show curr
  # Walks up until an element of seen_set or root is found.
  while true
    println("WALKING 2")
    @show curr.existence_node
    @show seen_set
    if curr.existence_node in seen_set
      lca = curr.existence_node
      @show lca
      break
    end

    isroot(curr) ? break : push!(walk_from2, curr)
    curr = proof.explain_find[curr.parent_connection.next]
  end

  ret = ProofNode[]
  @show lca
  # There's no LCA => there's no proof.
  lca == 0 && return ret

  for w in walk_from1
    push!(ret, w)
    w.existence_node == lca && break
  end

  # TODO maybe reverse
  append!(ret, walk_from2)
  ret
end

struct LeaderProof
  leader::Id
  proof::Vector{ProofNode}
end

function rewrite_to_leader(proof::EGraphProof, node::Id)::LeaderProof
  # Returns the leader of e-class and a proof to transform node into said leader
  curr_proof = proof.explain_find[node]
  proofs = []
  final_id = node
  if curr_proof.parent_connection.current == curr_proof.parent_connection.next
    return LeaderProof(node, [curr_proof]) # Special case to report congruence
  end
  while curr_proof.parent_connection.current != curr_proof.parent_connection.next
    push!(proofs, curr_proof)
    final_id = curr_proof.parent_connection.next
    curr_proof = proof.explain_find[curr_proof.parent_connection.next]
  end
  return LeaderProof(final_id, proofs)
end
