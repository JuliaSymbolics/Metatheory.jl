# Functional implementation of https://egraphs-good.github.io/
# https://dl.acm.org/doi/10.1145/3434304


# abstract type AbstractENode end

import Metatheory: maybelock!

const AnalysisData = NamedTuple{N,<:Tuple{Vararg{Ref}}} where {N}
const EClassId = Int64
const TermTypes = Dict{Tuple{Any,Int},Type}
# TODO document bindings
const Bindings = Base.ImmutableDict{Int,Tuple{Int,Int}}
const UNDEF_ARGS = Vector{EClassId}(undef, 0)

abstract type AbstractENode end

struct ENodeTerm <: AbstractENode
  # E-graph contains mappings from the UInt id of head, operation and symtype to their original value
  head::Any
  operation::Any
  args::Vector{EClassId}
  hash::Ref{UInt}
  ENodeTerm(head, operation, args) = new(head, operation, args, Ref{UInt}(0))
end

TermInterface.istree(n::ENodeTerm) = true
TermInterface.head(n::ENodeTerm) = n.head
TermInterface.operation(n::ENodeTerm) = n.operation
TermInterface.arguments(n::ENodeTerm) = n.args
TermInterface.children(n::ENodeTerm) = [n.operation; n.args...]
TermInterface.arity(n::ENodeTerm) = length(n.args)

struct ENodeLiteral <: AbstractENode
  value
  hash::Ref{UInt}
  ENodeLiteral(a) = new(a, Ref{UInt}(0))
end

Base.:(==)(a::ENodeLiteral, b::ENodeLiteral) = hash(a) == hash(b)

TermInterface.istree(n::ENodeLiteral) = false
TermInterface.operation(n::ENodeLiteral) = n.value
TermInterface.arity(n::ENodeLiteral) = 0

function Base.hash(t::ENodeLiteral, salt::UInt)
  !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
  h = t.hash[]
  !iszero(h) && return h
  h′ = hash(t.value, salt)
  t.hash[] = h′
  return h′
end


# This optimization comes from SymbolicUtils
# The hash of an enode is cached to avoid recomputing it.
# Shaves off a lot of time in accessing dictionaries with ENodes as keys.
function Base.hash(n::ENodeTerm, salt::UInt)
  !iszero(salt) && return hash(hash(n, zero(UInt)), salt)
  h = n.hash[]
  !iszero(h) && return h
  h′ = hash(n.args, hash(n.head, hash(n.operation, salt)))
  n.hash[] = h′
  return h′
end

function Base.:(==)(a::ENodeTerm, b::ENodeTerm)
  hash(a) == hash(b) && a.operation == b.operation
end

toexpr(n::ENodeLiteral) = n.value
toexpr(n::ENodeTerm) = Expr(:call, :ENodeTerm, head(n), operation(n), arguments(n))

Base.show(io::IO, x::AbstractENode) = print(io, toexpr(x))

op_key(n::ENodeLiteral) = (n.value => -1)
op_key(n::ENodeTerm) = (n.operation => arity(n))

# parametrize metadata by M
mutable struct EClass
  g # EGraph
  id::EClassId
  nodes::Vector{AbstractENode}
  parents::Vector{Pair{<:AbstractENode,EClassId}}
  data::AnalysisData
end

EClass(g, id) = EClass(g, id, AbstractENode[], Pair{AbstractENode,EClassId}[], nothing)
EClass(g, id, nodes, parents) = EClass(g, id, nodes, parents, NamedTuple())

# Interface for indexing EClass
Base.getindex(a::EClass, i) = a.nodes[i]
Base.setindex!(a::EClass, v, i) = setindex!(a.nodes, v, i)
Base.firstindex(a::EClass) = firstindex(a.nodes)
Base.lastindex(a::EClass) = lastindex(a.nodes)
Base.length(a::EClass) = length(a.nodes)

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

function addparent!(a::EClass, n::AbstractENode, id::EClassId)
  push!(a.parents, (n => id))
end

function merge_analysis_data!(g, a::EClass, b::EClass)::Tuple{Bool,Bool}
  if !isempty(a.data) && !isempty(b.data)
    new_a_data = Base.merge(a.data, b.data)
    for analysis_name in keys(b.data)
      analysis_ref = g.analyses[analysis_name]
      if hasproperty(a.data, analysis_name)
        ref = getproperty(new_a_data, analysis_name)
        ref[] = join(analysis_ref, ref[], getproperty(b.data, analysis_name)[])
      end
    end
    merged_a = (a.data == new_a_data)
    a.data = new_a_data
    (merged_a, b.data == new_a_data)
  elseif isempty(a.data) && !isempty(b.data)
    a.data = b.data
    # a merged, b not merged
    (true, false)
  elseif !isempty(a.data) && isempty(b.data)
    b.data = a.data
    (false, true)
  else
    (false, false)
  end
end

# Thanks to Shashi Gowda
hasdata(a::EClass, analysis_name::Symbol) = hasproperty(a.data, analysis_name)
hasdata(a::EClass, f::Function) = hasproperty(a.data, nameof(f))
getdata(a::EClass, analysis_name::Symbol) = getproperty(a.data, analysis_name)[]
getdata(a::EClass, f::Function) = getproperty(a.data, nameof(f))[]
getdata(a::EClass, analysis_ref::Union{Symbol,Function}, default) =
  hasdata(a, analysis_ref) ? getdata(a, analysis_ref) : default


setdata!(a::EClass, f::Function, value) = setdata!(a, nameof(f), value)
function setdata!(a::EClass, analysis_name::Symbol, value)
  if hasdata(a, analysis_name)
    ref = getproperty(a.data, analysis_name)
    ref[] = value
  else
    a.data = merge(a.data, NamedTuple{(analysis_name,)}((Ref{Any}(value),)))
  end
end

function funs(a::EClass)
  map(operation, a.nodes)
end

function funs_arity(a::EClass)
  map(a.nodes) do x
    (operation(x), arity(x))
  end
end

"""
A concrete type representing an [`EGraph`].
See the [egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304)
for implementation details.
"""
mutable struct EGraph
  "stores the equality relations over e-class ids"
  uf::UnionFind
  "map from eclass id to eclasses"
  classes::IdDict{EClassId,EClass}
  "hashcons"
  memo::Dict{AbstractENode,EClassId}
  "Nodes which need to be processed for rebuilding. The id is the id of the enode, not the canonical id of the eclass."
  pending::Vector{Pair{AbstractENode,EClassId}}
  analysis_pending::UniqueQueue{Pair{<:AbstractENode,EClassId}}
  root::EClassId
  "A vector of analyses associated to the EGraph"
  analyses::Dict{Union{Symbol,Function},Union{Symbol,Function}}
  "a cache mapping function symbols and their arity to e-classes that contain e-nodes with that function symbol."
  classes_by_op::Dict{Pair{Any,Int},Vector{EClassId}}
  head_type::Type
  clean::Bool
  "If we use global buffers we may need to lock. Defaults to true."
  needslock::Bool
  "Buffer for e-matching which defaults to a global. Use a local buffer for generated functions."
  buffer::Vector{Bindings}
  "Buffer for rule application which defaults to a global. Use a local buffer for generated functions."
  merges_buffer::Vector{Tuple{Int,Int}}
  lock::ReentrantLock
end


"""
    EGraph(expr)
Construct an EGraph from a starting symbolic expression `expr`.
"""
function EGraph(; needslock::Bool = false, head_type = ExprHead)
  EGraph(
    UnionFind(),
    Dict{EClassId,EClass}(),
    Dict{AbstractENode,EClassId}(),
    Pair{AbstractENode,EClassId}[],
    UniqueQueue{Pair{<:AbstractENode,EClassId}}(),
    -1,
    Dict{Union{Symbol,Function},Union{Symbol,Function}}(),
    Dict{Any,Vector{EClassId}}(),
    head_type,
    false,
    needslock,
    Bindings[],
    Tuple{Int,Int}[],
    ReentrantLock(),
  )
end

function maybelock!(f::Function, g::EGraph)
  g.needslock ? lock(f, g.buffer_lock) : f()
end

function EGraph(e; keepmeta = false, kwargs...)
  g = EGraph(; kwargs...)
  keepmeta && addanalysis!(g, :metadata_analysis)
  g.root = addexpr!(g, e, keepmeta)
  g
end

function addanalysis!(g::EGraph, costfun::Function)
  g.analyses[nameof(costfun)] = costfun
  g.analyses[costfun] = costfun
end

function addanalysis!(g::EGraph, analysis_name::Symbol)
  g.analyses[analysis_name] = analysis_name
end


total_size(g::EGraph) = length(g.memo)

"""
Returns the canonical e-class id for a given e-class.
"""
find(g::EGraph, a::EClassId)::EClassId = find(g.uf, a)
find(g::EGraph, a::EClass)::EClassId = find(g, a.id)

Base.getindex(g::EGraph, i::EClassId) = g.classes[find(g, i)]

canonicalize(g::EGraph, n::ENodeLiteral)::ENodeLiteral = n

function canonicalize(g::EGraph, n::ENodeTerm)::ENodeTerm
  ar = length(n.args)
  ar == 0 && return n
  canonicalized_args = Vector{EClassId}(undef, ar)
  for i in 1:ar
    @inbounds canonicalized_args[i] = find(g, n.args[i])
  end
  ENodeTerm(head(n), operation(n), canonicalized_args)
end

canonicalize!(g::EGraph, n::ENodeLiteral) = n
function canonicalize!(g::EGraph, n::ENodeTerm)
  for (i, arg) in enumerate(n.args)
    @inbounds n.args[i] = find(g, arg)
  end
  n.hash[] = UInt(0)
  return n
end


function canonicalize!(g::EGraph, e::EClass)
  e.id = find(g, e.id)
end

function lookup(g::EGraph, n::AbstractENode)::EClassId
  cc = canonicalize(g, n)
  haskey(g.memo, cc) ? find(g, g.memo[cc]) : -1
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
function add!(g::EGraph, n::AbstractENode)::EClassId
  n = canonicalize(g, n)
  haskey(g.memo, n) && return g.memo[n]

  id = push!(g.uf) # create new singleton eclass

  if n isa ENodeTerm
    for c_id in n.args
      addparent!(g.classes[c_id], n, id)
    end
  end

  g.memo[n] = id

  add_class_by_op(g, n, id)
  classdata = EClass(g, id, AbstractENode[n], Pair{AbstractENode,EClassId}[])
  g.classes[id] = classdata
  push!(g.pending, n => id)

  for an in values(g.analyses)
    if !islazy(an) && an !== :metadata_analysis
      setdata!(classdata, an, make(an, g, n))
      modify!(an, g, id)
    end
  end
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
function addexpr!(g::EGraph, se, keepmeta = false)::EClassId
  se isa EClass && return se.id
  e = preprocess(se)

  n = if istree(se)
    args = arguments(e)
    ar = length(args)
    class_ids = Vector{EClassId}(undef, ar)
    for i in 1:ar
      @inbounds class_ids[i] = addexpr!(g, args[i], keepmeta)
    end
    ENodeTerm(head(e), operation(e), class_ids)
  else # constant enode
    ENodeLiteral(e)
  end
  id = add!(g, n)
  if keepmeta
    meta = TermInterface.metadata(e)
    !isnothing(meta) && setdata!(g.classes[id], :metadata_analysis, meta)
  end
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

  eclass_2 = g.classes[id_2]::EClass
  delete!(g.classes, id_2)
  eclass_1 = g.classes[id_1]::EClass

  append!(g.pending, eclass_2.parents)

  (merged_1, merged_2) = merge_analysis_data!(g, eclass_1, eclass_2)
  merged_1 && append!(g.analysis_pending, eclass_1.parents)
  merged_2 && append!(g.analysis_pending, eclass_2.parents)


  append!(eclass_1.nodes, eclass_2.nodes)
  append!(eclass_1.parents, eclass_2.parents)
  # I (was) the troublesome line!
  # g.classes[to] = union!(to_class, from_class)
  # delete!(g.classes, from)
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

    # Sort and dedup to go in order?
    for n in eclass.nodes
      add_class_by_op(g, n, eclass_id)
    end
  end

  # TODO is this needed?
  for v in values(g.classes_by_op)
    unique!(v)
  end
end

function process_unions!(g::EGraph)::Int
  n_unions = 0

  while !isempty(g.pending) || !isempty(g.analysis_pending)
    while !isempty(g.pending)
      (node::AbstractENode, eclass_id::EClassId) = pop!(g.pending)
      canonicalize!(g, node)
      if haskey(g.memo, node)
        old_class_id = g.memo[node]
        g.memo[node] = eclass_id
        did_something = union!(g, old_class_id, eclass_id)
        n_unions += did_something
      end
    end

    while !isempty(g.analysis_pending)
      (node::AbstractENode, eclass_id::EClassId) = pop!(g.analysis_pending)
      eclass_id = find(g, eclass_id)
      eclass = g[eclass_id]

      for an in values(g.analyses)

        an === :metadata_analysis && continue

        node_data = make(an, g, node)
        if hasdata(eclass, an)
          class_data = getdata(eclass, an)

          joined_data = join(an, class_data, node_data)

          if joined_data != class_data
            setdata!(eclass, an, joined_data)
            modify!(an, g, eclass_id)
            append!(g.analysis_pending, eclass.parents)
          end
        elseif !islazy(an)
          setdata!(eclass, an, node_data)
          modify!(an, g, eclass_id)
        end
      end
    end
  end
  n_unions
end

function check_memo(g::EGraph)::Bool
  test_memo = Dict{AbstractENode,EClassId}()
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
    for an in values(g.analyses)
      an == :metadata_analysis && continue
      islazy(an) || (@assert hasdata(eclass, an))
      hasdata(eclass, an) || continue
      pass = mapreduce(x -> make(an, g, x), (x, y) -> join(an, x, y), eclass)
      @assert getdata(eclass, an) == pass
    end
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

  reachable_node(xn::ENodeLiteral) = nothing
  function reachable_node(xn::ENodeTerm)
    x = canonicalize(g, xn)
    for c_id in arguments(x)
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

function lookup_pat(g::EGraph, p::PatTerm)::EClassId
  @assert isground(p)

  op = operation(p)
  args = arguments(p)
  ar = arity(p)

  eh = g.head_type(head_symbol(head(p)))

  ids = map(x -> lookup_pat(g, x), args)
  !all((>)(0), ids) && return -1

  if g.head_type == ExprHead && op isa Union{Function,DataType}
    id = lookup(g, ENodeTerm(eh, op, ids))
    id < 0 ? lookup(g, ENodeTerm(eh, nameof(op), ids)) : id
  else
    lookup(g, ENodeTerm(eh, op, ids))
  end
end

lookup_pat(g::EGraph, p::Any) = lookup(g, ENodeLiteral(p))
lookup_pat(g::EGraph, p::AbstractPat) = throw(UnsupportedPatternException(p))
