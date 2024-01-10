# Functional implementation of https://egraphs-good.github.io/
# https://dl.acm.org/doi/10.1145/3434304

import Metatheory: maybelock!

"""
    modify!(eclass::EClass{Analysis})

The `modify!` function for EGraph Analysis can optionally modify the eclass
`eclass` after it has been analyzed, typically by adding an ENode.
It should be **idempotent** if no other changes occur to the EClass. 
(See the [egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304)).
"""
function modify! end


"""
    join(a::AnalysisType, b::AnalysisType)::AnalysisType

Joins two analyses values into a single one, used by [analyze!](@ref)
when two eclasses are being merged or the analysis is being constructed.
"""
function join end

"""
    make(g::EGraph{Head, AnalysisType}, n::ENode)::AnalysisType where Head

Given an ENode `n`, `make` should return the corresponding analysis value. 
"""
function make end

const EClassId = UInt64
# TODO document bindings
const Bindings = Base.ImmutableDict{Int,Tuple{EClassId,Int}}
const UNDEF_ID_VEC = Vector{EClassId}(undef, 0)

# @compactify begin 
struct ENode
  # TODO use UInt flags
  istree::Bool
  head::Any
  operation::Any
  args::Vector{EClassId}
  hash::Ref{UInt}
  ENode(head, operation, args) = new(true, head, operation, args, Ref{UInt}(0))
  ENode(literal) = new(false, nothing, literal, UNDEF_ID_VEC, Ref{UInt}(0))
end

TermInterface.istree(n::ENode) = n.istree
TermInterface.head(n::ENode) = n.head
TermInterface.operation(n::ENode) = n.operation
TermInterface.arguments(n::ENode) = n.args
TermInterface.children(n::ENode) = [n.operation; n.args...]
TermInterface.arity(n::ENode)::Int = length(n.args)


# This optimization comes from SymbolicUtils
# The hash of an enode is cached to avoid recomputing it.
# Shaves off a lot of time in accessing dictionaries with ENodes as keys.
function Base.hash(n::ENode, salt::UInt)
  !iszero(salt) && return hash(hash(n, zero(UInt)), salt)
  h = n.hash[]
  !iszero(h) && return h
  h′ = hash(n.args, hash(n.head, hash(n.operation, hash(n.istree, salt))))
  n.hash[] = h′
  return h′
end

function Base.:(==)(a::ENode, b::ENode)
  hash(a) == hash(b) && a.operation == b.operation
end

function to_expr(n::ENode)
  n.istree || return n.operation
  Expr(:call, :ENode, head(n), operation(n), arguments(n))
end

Base.show(io::IO, x::ENode) = print(io, to_expr(x))

function op_key(n)::Pair{Any,Int}
  op = operation(n)
  (op isa Union{Function,DataType} ? nameof(op) : op) => (istree(n) ? arity(n) : -1)
end

# parametrize metadata by M
mutable struct EClass{D}
  id::EClassId
  nodes::Vector{ENode}
  parents::Vector{Pair{ENode,EClassId}}
  data::Union{D,Nothing}
end

# Interface for indexing EClass
Base.getindex(a::EClass, i) = a.nodes[i]

# Interface for iterating EClass
Base.iterate(a::EClass) = iterate(a.nodes)
Base.iterate(a::EClass, state) = iterate(a.nodes, state)

# Showing
function Base.show(io::IO, a::EClass)
  print(io, "EClass $(a.id) (")

  print(io, "[", Base.join(a.nodes, ", "), "], ")
  print(io, a.data)
  print(io, ")")
end

function addparent!(@nospecialize(a::EClass), n::ENode, id::EClassId)
  push!(a.parents, (n => id))
end


function merge_analysis_data!(@nospecialize(a::EClass), @nospecialize(b::EClass))::Tuple{Bool,Bool}
  if !isnothing(a.data) && !isnothing(b.data)
    new_a_data = join(a.data, b.data)
    merged_a = (a.data == new_a_data)
    a.data = new_a_data
    (merged_a, b.data == new_a_data)
  elseif !isnothing(a.data) && !isnothing(b.data)
    a.data = b.data
    # a merged, b not merged
    (true, false)
  elseif !isnothing(a.data) && !isnothing(b.data)
    b.data = a.data
    (false, true)
  else
    (false, false)
  end
end


"""
A concrete type representing an [`EGraph`].
See the [egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304)
for implementation details.
"""
mutable struct EGraph{Head,Analysis}
  "stores the equality relations over e-class ids"
  uf::UnionFind
  "map from eclass id to eclasses"
  classes::Dict{EClassId,EClass{Analysis}}
  "hashcons"
  memo::Dict{ENode,EClassId}
  "Nodes which need to be processed for rebuilding. The id is the id of the enode, not the canonical id of the eclass."
  pending::Vector{Pair{ENode,EClassId}}
  analysis_pending::UniqueQueue{Pair{ENode,EClassId}}
  root::EClassId
  "a cache mapping function symbols and their arity to e-classes that contain e-nodes with that function symbol."
  classes_by_op::Dict{Pair{Any,Int},Vector{EClassId}}
  clean::Bool
  "If we use global buffers we may need to lock. Defaults to false."
  needslock::Bool
  "Buffer for e-matching which defaults to a global. Use a local buffer for generated functions."
  buffer::Vector{Bindings}
  "Buffer for rule application which defaults to a global. Use a local buffer for generated functions."
  merges_buffer::Vector{EClassId}
  lock::ReentrantLock
end


"""
    EGraph(expr)
Construct an EGraph from a starting symbolic expression `expr`.
"""
function EGraph{Head,Analysis}(; needslock::Bool = false) where {Head,Analysis}
  EGraph{Head,Analysis}(
    UnionFind(),
    Dict{EClassId,EClass{Analysis}}(),
    Dict{ENode,EClassId}(),
    Pair{ENode,EClassId}[],
    UniqueQueue{Pair{ENode,EClassId}}(),
    0,
    Dict{Pair{Any,Int},Vector{EClassId}}(),
    false,
    needslock,
    Bindings[],
    EClassId[],
    ReentrantLock(),
  )
end
EGraph(; kwargs...) = EGraph{ExprHead,Nothing}(; kwargs...)
EGraph{Head}(; kwargs...) where {Head} = EGraph{Head,Nothing}(; kwargs...)

function EGraph{Head,Analysis}(e; kwargs...) where {Head,Analysis}
  g = EGraph{Head,Analysis}(; kwargs...)
  g.root = addexpr!(g, e)
  g
end

EGraph{Head}(e; kwargs...) where {Head} = EGraph{Head,Nothing}(e; kwargs...)
EGraph(e; kwargs...) = EGraph{typeof(head(e)),Nothing}(e; kwargs...)

# Fallback implementation for analysis methods make and modify
@inline make(::EGraph, ::ENode) = nothing
@inline modify!(::EGraph, ::EClass{Analysis}) where {Analysis} = nothing


function maybelock!(f::Function, g::EGraph)
  g.needslock ? lock(f, g.buffer_lock) : f()
end


"""
Returns the canonical e-class id for a given e-class.
"""
@inline find(g::EGraph, a::EClassId)::EClassId = find(g.uf, a)
@inline find(@nospecialize(g::EGraph), @nospecialize(a::EClass))::EClassId = find(g, a.id)

@inline Base.getindex(g::EGraph, i::EClassId) = g.classes[find(g, i)]

function canonicalize(g::EGraph, n::ENode)::ENode
  n.istree || return n
  ar = length(n.args)
  ar == 0 && return n
  canonicalized_args = Vector{EClassId}(undef, ar)
  for i in 1:ar
    @inbounds canonicalized_args[i] = find(g, n.args[i])
  end
  ENode(head(n), operation(n), canonicalized_args)
end

function canonicalize!(g::EGraph, n::ENode)
  n.istree || return n
  for (i, arg) in enumerate(n.args)
    @inbounds n.args[i] = find(g, arg)
  end
  n.hash[] = UInt(0)
  return n
end

function lookup(g::EGraph, n::ENode)::EClassId
  cc = canonicalize(g, n)
  haskey(g.memo, cc) ? find(g, g.memo[cc]) : 0
end


function add_class_by_op(g::EGraph, n, eclass_id)
  key = op_key(n)
  if haskey(g.classes_by_op, key)
    push!(g.classes_by_op[key], eclass_id)
  else
    g.classes_by_op[key] = [eclass_id]
  end
end

"""
Inserts an e-node in an [`EGraph`](@ref)
"""
function add!(g::EGraph{Head,Analysis}, n::ENode)::EClassId where {Head,Analysis}
  n = canonicalize(g, n)
  haskey(g.memo, n) && return g.memo[n]

  id = push!(g.uf) # create new singleton eclass

  if n.istree
    for c_id in n.args
      addparent!(g.classes[c_id], n, id)
    end
  end

  g.memo[n] = id

  add_class_by_op(g, n, id)
  eclass = EClass{Analysis}(id, ENode[n], Pair{ENode,EClassId}[], make(g, n))
  g.classes[id] = eclass
  modify!(g, eclass)
  push!(g.pending, n => id)

  return id
end


"""
Extend this function on your types to do preliminary
preprocessing of a symbolic term before adding it to 
an EGraph. Most common preprocessing techniques are binarization
of n-ary terms and metadata stripping.
"""
function preprocess(e::Expr)
  cleanast(e)
end
preprocess(x) = x

"""
Recursively traverse an type satisfying the `TermInterface` and insert terms into an
[`EGraph`](@ref). If `e` has no children (has an arity of 0) then directly
insert the literal into the [`EGraph`](@ref).
"""
function addexpr!(g::EGraph, se)::EClassId
  se isa EClass && return se.id
  e = preprocess(se)

  n = if istree(se)
    args = arguments(e)
    ar = arity(e)
    class_ids = Vector{EClassId}(undef, ar)
    for i in 1:ar
      @inbounds class_ids[i] = addexpr!(g, args[i])
    end
    ENode(head(e), operation(e), class_ids)
  else # constant enode
    ENode(e)
  end
  id = add!(g, n)
  return id
end

"""
Given an [`EGraph`](@ref) and two e-class ids, set
the two e-classes as equal.
"""
function Base.union!(g::EGraph, enode_id1::EClassId, enode_id2::EClassId)::Bool
  g.clean = false

  id_1 = find(g, enode_id1)
  id_2 = find(g, enode_id2)

  id_1 == id_2 && return false

  # Make sure class 2 has fewer parents
  if length(g.classes[id_1].parents) < length(g.classes[id_2].parents)
    id_1, id_2 = id_2, id_1
  end

  union!(g.uf, id_1, id_2)

  eclass_2 = pop!(g.classes, id_2)::EClass
  eclass_1 = g.classes[id_1]::EClass

  append!(g.pending, eclass_2.parents)

  (merged_1, merged_2) = merge_analysis_data!(eclass_1, eclass_2)
  merged_1 && append!(g.analysis_pending, eclass_1.parents)
  merged_2 && append!(g.analysis_pending, eclass_2.parents)


  append!(eclass_1.nodes, eclass_2.nodes)
  append!(eclass_1.parents, eclass_2.parents)
  return true
end

function in_same_class(g::EGraph, ids::EClassId...)::Bool
  nids = length(ids)
  nids == 1 && return true

  # @show map(x -> find(g, x), ids)
  first_id = find(g, ids[1])
  for i in 2:nids
    first_id == find(g, ids[i]) || return false
  end
  true
end


function rebuild_classes!(g::EGraph)
  for v in values(g.classes_by_op)
    empty!(v)
  end

  for (eclass_id, eclass::EClass) in g.classes
    # old_len = length(eclass.nodes)
    for n in eclass.nodes
      canonicalize!(g, n)
    end
    # Sort to go in order?
    unique!(eclass.nodes)

    for n in eclass.nodes
      add_class_by_op(g, n, eclass_id)
    end
  end

  # TODO is this needed?
  for v in values(g.classes_by_op)
    unique!(v)
  end
end

function process_unions!(@nospecialize(g::EGraph))::Int
  n_unions = 0

  while !isempty(g.pending) || !isempty(g.analysis_pending)
    while !isempty(g.pending)
      (node::ENode, eclass_id::EClassId) = pop!(g.pending)
      canonicalize!(g, node)
      if haskey(g.memo, node)
        old_class_id = g.memo[node]
        g.memo[node] = eclass_id
        did_something = union!(g, old_class_id, eclass_id)
        # TODO unique! node dedup can be moved here? compare performance
        # did_something && unique!(g[eclass_id].nodes)
        n_unions += did_something
      end
    end

    while !isempty(g.analysis_pending)
      (node::ENode, eclass_id::EClassId) = pop!(g.analysis_pending)
      eclass_id = find(g, eclass_id)
      eclass = g[eclass_id]

      node_data = make(g, node)
      if !isnothing(eclass.data)
        joined_data = join(eclass.data, node_data)

        if joined_data != eclass.data
          setdata!(eclass, an, joined_data)
          modify!(g, eclass)
          append!(g.analysis_pending, eclass.parents)
        end
      else
        eclass.data = node_data
        modify!(g, eclass)
      end

    end
  end
  n_unions
end

function check_memo(g::EGraph)::Bool
  test_memo = Dict{ENode,EClassId}()
  for (id, class) in g.classes
    @assert id == class.id
    for node in class.nodes
      if haskey(test_memo, node)
        old_id = test_memo[node]
        test_memo[node] = id
        @assert find(g, old_id) == find(g, id) "Unexpected equivalence $node $(g[find(g, id)].nodes) $(g[find(g, old_id)].nodes)"
      end
    end
  end

  for (node, id) in test_memo
    @assert id == find(g, id)
    @assert id == find(g, g.memo[node])
  end

  true
end

function check_analysis(g)
  for (id, eclass) in g.classes
    isnothing(eclass.data) && continue
    pass = mapreduce(x -> make(g, x), (x, y) -> join(x, y), eclass)
    @assert eclass.data == pass
  end
  true
end

"""
This function restores invariants and executes
upwards merging in an [`EGraph`](@ref). See
the [egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304)
for more details.
"""
function rebuild!(g::EGraph)
  n_unions = process_unions!(g)
  trimmed_nodes = rebuild_classes!(g)
  # @assert check_memo(g)
  # @assert check_analysis(g)
  g.clean = true

  @debug "REBUILT" n_unions trimmed_nodes
end

"""
Recursive function that traverses an [`EGraph`](@ref) and
returns a vector of all reachable e-classes from a given e-class id.
"""
function reachable(g::EGraph, id::EClassId)
  id = find(g, id)
  hist = EClassId[id]
  todo = EClassId[id]


  function reachable_node(xn::ENode)
    xn.istree || return
    for c_id in arguments(xn)
      if c_id ∉ hist
        push!(hist, c_id)
        push!(todo, c_id)
      end
    end
  end

  while !isempty(todo)
    curr = find(g, pop!(todo))
    for n in g.classes[curr]
      reachable_node(n)
    end
  end

  return hist
end

# Thanks to Max Willsey and Yihong Zhang

import Metatheory: lookup_pat

function lookup_pat(g::EGraph{Head}, p::PatTerm)::EClassId where {Head}
  @assert isground(p)

  op = operation(p)
  args = arguments(p)
  ar = arity(p)

  eh = Head(head_symbol(head(p)))

  ids = Vector{EClassId}(undef, ar)
  for i in 1:ar
    @inbounds ids[i] = lookup_pat(g, args[i])
    ids[i] <= 0 && return 0
  end

  if Head == ExprHead && op isa Union{Function,DataType}
    id = lookup(g, ENode(eh, op, ids))
    id <= 0 ? lookup(g, ENode(eh, nameof(op), ids)) : id
  else
    lookup(g, ENode(eh, op, ids))
  end
end

lookup_pat(g::EGraph, p::Any)::EClassId = lookup(g, ENode(p))
