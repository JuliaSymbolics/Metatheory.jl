# Functional implementation of https://egraphs-good.github.io/
# https://dl.acm.org/doi/10.1145/3434304


"""
    modify!(eclass::EClass{Analysis})

The `modify!` function for EGraph Analysis can optionally modify the eclass
`eclass` after it has been analyzed, typically by adding an e-node.
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
    make(g::EGraph{ExpressionType, AnalysisType}, n::VecExpr)::AnalysisType where {ExpressionType}

Given an e-node `n`, `make` should return the corresponding analysis value. 
"""
function make end


# TODO parametrize metadata by M
"""
    EClass{D}

An `EClass` is an equivalence class of terms.

The children and parent nodes are stored as [`VecExpr`](@ref)s for performance, which
means that without a reference to the [`EGraph`](@ref) object we cannot re-build human-readable terms
they represent. The [`EGraph`](@ref) itself comes with pretty printing for humean-readable terms.
"""
mutable struct EClass{D}
  id::Id
  nodes::Vector{VecExpr}
  parents::Vector{Pair{VecExpr,Id}}
  data::Union{D,Nothing}
end

# Interface for indexing EClass
Base.getindex(a::EClass, i) = a.nodes[i]

# Interface for iterating EClass
Base.iterate(a::EClass) = iterate(a.nodes)
Base.iterate(a::EClass, state) = iterate(a.nodes, state)

# Showing
function Base.show(io::IO, a::EClass)
  println(io, "$(typeof(a)) %$(a.id) with $(length(a.nodes)) e-nodes:")
  println(io, " data: $(a.data)")
  println(io, " nodes:")
  for n in a.nodes
    println(io, "    $n")
  end
end

function addparent!(@nospecialize(a::EClass), n::VecExpr, id::Id)
  push!(a.parents, (n => id))
end


function merge_analysis_data!(@nospecialize(a::EClass), @nospecialize(b::EClass))::Tuple{Bool,Bool}
  if !isnothing(a.data) && !isnothing(b.data)
    new_a_data = join(a.data, b.data)
    merged_a = (a.data == new_a_data)
    a.data = new_a_data
    (merged_a, b.data == new_a_data)
  elseif isnothing(a.data) && !isnothing(b.data)
    a.data = b.data
    # a merged, b not merged
    (true, false)
  elseif !isnothing(a.data) && isnothing(b.data)
    b.data = a.data
    (false, true)
  else
    (false, false)
  end
end


"""
    EGraph{ExpressionType,Analysis}

A concrete type representing an *e-graph*.

An [`EGraph`](@ref) is a set of equivalence classes ([`EClass`](@ref)).
An `EClass` is in turn a set of e-nodes representing equivalent terms.
An e-node points to a set of children e-classes.
In Metatheory.jl, an e-node is implemented as a [`VecExpr`](@ref) for performance reasons.
The IDs stored in an e-node (i.e. `VecExpr`) or an `EClass` by themselves are
not necessarily very informative, but you can access the terms of each e-node
via `Metatheory.to_expr`.

See the [egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304)
for implementation details.
"""
mutable struct EGraph{ExpressionType,Analysis}
  "stores the equality relations over e-class ids"
  uf::UnionFind
  "map from eclass id to eclasses"
  classes::Dict{Id,EClass{Analysis}}
  "hashcons mapping e-node hashes to their e-class id"
  memo::Dict{Id,Id}
  "Hashcons the constants in the e-graph"
  constants::Dict{UInt64,Any}
  "Nodes which need to be processed for rebuilding. The id is the id of the enode, not the canonical id of the eclass."
  pending::Vector{Pair{VecExpr,Id}}
  analysis_pending::UniqueQueue{Pair{VecExpr,Id}}
  root::Id
  "a cache mapping function symbols and their arity to e-classes that contain e-nodes with that function symbol."
  classes_by_op::Dict{Pair{Id,Int},Vector{Id}}
  clean::Bool
  "If we use global buffers we may need to lock. Defaults to false."
  needslock::Bool
  "Buffer for e-matching which defaults to a global. Use a local buffer for generated functions."
  buffer::Vector{Bindings}
  "Buffer for rule application which defaults to a global. Use a local buffer for generated functions."
  merges_buffer::Vector{Id}
  lock::ReentrantLock
end


"""
    EGraph(expr)
Construct an EGraph from a starting symbolic expression `expr`.
"""
function EGraph{ExpressionType,Analysis}(; needslock::Bool = false) where {ExpressionType,Analysis}
  EGraph{ExpressionType,Analysis}(
    UnionFind(),
    Dict{Id,EClass{Analysis}}(),
    Dict{Id,Id}(),
    Dict{UInt64,Any}(),
    Pair{VecExpr,Id}[],
    UniqueQueue{Pair{VecExpr,Id}}(),
    0,
    Dict{Pair{Any,Int},Vector{Id}}(),
    false,
    needslock,
    Bindings[],
    Id[],
    ReentrantLock(),
  )
end
EGraph(; kwargs...) = EGraph{Expr,Nothing}(; kwargs...)
EGraph{ExpressionType}(; kwargs...) where {ExpressionType} = EGraph{ExpressionType,Nothing}(; kwargs...)

function EGraph{ExpressionType,Analysis}(e; kwargs...) where {ExpressionType,Analysis}
  g = EGraph{ExpressionType,Analysis}(; kwargs...)
  g.root = addexpr!(g, e)
  g
end

EGraph{ExpressionType}(e; kwargs...) where {ExpressionType} = EGraph{ExpressionType,Nothing}(e; kwargs...)
EGraph(e; kwargs...) = EGraph{typeof(e),Nothing}(e; kwargs...)

# Fallback implementation for analysis methods make and modify
@inline make(::EGraph, ::VecExpr) = nothing
@inline modify!(::EGraph, ::EClass{Analysis}) where {Analysis} = nothing


function maybelock!(f::Function, g::EGraph)
  g.needslock ? lock(f, g.buffer_lock) : f()
end


@inline get_constant(@nospecialize(g::EGraph), hash::UInt64) = g.constants[hash]
@inline has_constant(@nospecialize(g::EGraph), hash::UInt64)::Bool = haskey(g.constants, hash)
@inline function add_constant!(@nospecialize(g::EGraph), @nospecialize(c))::Id
  h = hash(c)
  get!(g.constants, h, c)
  h
end
function to_expr(g::EGraph, n::VecExpr)
  v_isexpr(n) || return get_constant(g, v_head(n))
  h = get_constant(g, v_head(n))
  args = Core.SSAValue.(Int.(v_children(n)))
  if v_iscall(n)
    maketerm(Expr, :call, [h; args])
  else
    maketerm(Expr, h, args)
  end
end

function pretty_dict(g::EGraph)
  d = Dict{Int,Vector{Any}}()
  for (class_id, eclass) in g.classes
    d[class_id] = map(n -> to_expr(g, n), eclass.nodes)
  end
  d
end
export pretty_dict

function Base.show(io::IO, g::EGraph)
  d = pretty_dict(g)
  t = "$(typeof(g)) with $(length(d)) e-classes:"
  cs = map(collect(d)) do (k,vect)
    "  $k => [$(Base.join(vect, ", "))]"
  end
  print(io, Base.join([t; cs], "\n"))
end

function enode_op_key(@nospecialize(g::EGraph), n::VecExpr)::Pair{UInt64,Int}
  h = v_head(n)
  op = get_constant(g, h)
  if op isa Union{Function,DataType}
    # h = add_constant!(g, nameof(op))
    op = nameof(op)
  end
  hash(op) => (v_isexpr(n) ? v_arity(n) : -1)
end

# TODO use flags!
function op_key(t)::Pair{UInt64,Int}
  h = head(t)
  if h isa Union{Function,DataType}
    h = nameof(h)
  end
  (hash(h) => (isexpr(t) ? arity(t) : -1))
end

"""
Returns the canonical e-class id for a given e-class.
"""
@inline find(g::EGraph, a::Id)::Id = find(g.uf, a)
@inline find(@nospecialize(g::EGraph), @nospecialize(a::EClass))::Id = find(g, a.id)

@inline Base.getindex(g::EGraph, i::Id) = g.classes[find(g, i)]

# function canonicalize(g::EGraph, n::VecExpr)::VecExpr
#   if !v_isexpr(n)
#     v_hash!(n)
#     return n
#   end
#   l = v_arity(n)
#   new_n = v_new(l)
#   v_set_flag!(new_n, v_flags(n))
#   v_set_head!(new_n, v_head(n))
#   for i in v_children_range(n)
#     @inbounds new_n[i] = find(g, n[i])
#   end
#   v_hash!(new_n)
#   new_n
# end

function canonicalize!(g::EGraph, n::VecExpr)
  v_isexpr(n) || @goto ret
  for i in 4:length(n)
    @inbounds n[i] = find(g, n[i])
  end
  v_unset_hash!(n)
  @label ret
  v_hash!(n)
  n
end

function lookup(g::EGraph, n::VecExpr)::Id
  canonicalize!(g, n)
  h = v_hash(n)

  haskey(g.memo, h) ? find(g, g.memo[h]) : 0
end


function add_class_by_op(g::EGraph, n, eclass_id)
  key = enode_op_key(g, n)
  if haskey(g.classes_by_op, key)
    push!(g.classes_by_op[key], eclass_id)
  else
    g.classes_by_op[key] = [eclass_id]
  end
end

"""
Inserts an e-node in an [`EGraph`](@ref)
"""
function add!(g::EGraph{ExpressionType,Analysis}, n::VecExpr)::Id where {ExpressionType,Analysis}
  canonicalize!(g, n)
  h = v_hash(n)

  haskey(g.memo, h) && return g.memo[h]


  id = push!(g.uf) # create new singleton eclass

  if v_isexpr(n)
    for c_id in v_children(n)
      addparent!(g.classes[c_id], n, id)
    end
  end

  g.memo[h] = id

  add_class_by_op(g, n, id)
  eclass = EClass{Analysis}(id, VecExpr[n], Pair{VecExpr,Id}[], make(g, n))
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
function addexpr!(g::EGraph, se)::Id
  se isa EClass && return se.id
  e = preprocess(se)

  n = if isexpr(e)
    args = iscall(e) ? arguments(e) : children(e)
    ar = length(args)
    has_symtype = typeof(se) != symtype(se)

    # Expression has a symtype, add space for type
    has_symtype && (ar += 1)

    n = v_new(ar)
    v_set_flag!(n, VECEXPR_FLAG_ISEXPR)
    iscall(e) && v_set_flag!(n, VECEXPR_FLAG_ISCALL)

    
    h = iscall(e) ? operation(e) : head(e)
    v_set_head!(n, add_constant!(g, h))
    
    for i in v_children_range(n)
      @inbounds n[i] = addexpr!(g, args[i - VECEXPR_META_LENGTH])
    end

    has_symtype && v_set_symtype!(n, add_constant!(g, symtype(se)))
    n
  else # constant enode
    Id[Id(0), Id(0), add_constant!(g, e)]
  end
  id = add!(g, n)
  return id
end

"""
Given an [`EGraph`](@ref) and two e-class ids, set
the two e-classes as equal.
"""
function Base.union!(g::EGraph, enode_id1::Id, enode_id2::Id)::Bool
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

function in_same_class(g::EGraph, ids::Id...)::Bool
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
      (node::VecExpr, eclass_id::Id) = pop!(g.pending)
      canonicalize!(g, node)
      h = v_hash(node)
      if haskey(g.memo, h)
        old_class_id = g.memo[h]
        g.memo[h] = eclass_id
        did_something = union!(g, old_class_id, eclass_id)
        # TODO unique! can node dedup be moved here? compare performance
        # did_something && unique!(g[eclass_id].nodes)
        n_unions += did_something
      end
    end

    while !isempty(g.analysis_pending)
      (node::VecExpr, eclass_id::Id) = pop!(g.analysis_pending)
      eclass_id = find(g, eclass_id)
      eclass = g[eclass_id]

      node_data = make(g, node)
      if !isnothing(eclass.data)
        joined_data = join(eclass.data, node_data)

        if joined_data != eclass.data
          eclass.data = joined_data
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
  test_memo = Dict{VecExpr,Id}()
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
    @assert id == find(g, g.memo[v_hash(node)])
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

# Thanks to Max Willsey and Yihong Zhang


function lookup_pat(g::EGraph{ExpressionType}, p::PatExpr)::Id where {ExpressionType}
  @assert isground(p)

  op = head(p)
  args = children(p)
  ar = arity(p)
  p_iscall = iscall(p)


  has_op = has_constant(g, p.head_hash)
  if !has_op && ExpressionType === Expr && op isa Union{Function,DataType}
    has_op = has_constant(g, hash(nameof(op)))
  end
  has_op || return 0

  n = v_new(ar)
  v_set_flag!(n, VECEXPR_FLAG_ISEXPR)
  p_iscall && v_set_flag!(n, VECEXPR_FLAG_ISCALL)
  v_set_head!(n, p.head_hash)

  for i in v_children_range(n)
    @inbounds n[i] = lookup_pat(g, args[i - VECEXPR_META_LENGTH])
    n[i] <= 0 && return 0
  end

  id = lookup(g, n)
  if id <= 0 && ExpressionType == Expr && op isa Union{Function,DataType}
    v_set_head!(n, hash(nameof(op)))
    id = lookup(g, n)
  end
  id
end

function lookup_pat(g::EGraph, p::Any)::Id
  h = hash(p)
  has_constant(g, h) ? lookup(g, Id[0, 0, h]) : 0
end
