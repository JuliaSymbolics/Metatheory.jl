export ProofConnection, ProofNode, EGraphProof

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
  new_parent_connection =
    ProofConnection(-old_parent_connection.justification, old_parent_connection.node, old_parent_conneection.next)

  proof.explain_find[next].parent_connection = new_parent_connection
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

  pconnection = ProofConnection(rule_idx, node2, node1)
  other_pconnection = ProofConnection(-rule_idx, node2, node1)


  push!(proof_node1.neighbours, pconnection)
  push!(proof_node2.neighbours, other_pconnection)

  # TODO WAT???
  proof_node1.parent_connection = pconnection
end

