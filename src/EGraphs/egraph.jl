# Functional implementation of https://egraphs-good.github.io/
# https://dl.acm.org/doi/10.1145/3434304

# ==============================================================
# Interface to implement for custom analyses
# ==============================================================

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

# ==============================================================
# EClasses
# ==============================================================

"""
    EClass{D}

An `EClass` is an equivalence class of terms.

The children and parent nodes are stored as [`VecExpr`](@ref)s for performance, which
means that without a reference to the [`EGraph`](@ref) object we cannot re-build human-readable terms
they represent. The [`EGraph`](@ref) itself comes with pretty printing for human-readable terms.
"""
mutable struct EClass{D}
  const id::Id
  const nodes::Vector{VecExpr}
  const parents::Vector{Pair{VecExpr,Id}}
  data::Union{D,Nothing}
end

# Interface for indexing EClass
Base.getindex(a::EClass, i) = a.nodes[i]

# Interface for iterating EClass
Base.iterate(a::EClass) = iterate(a.nodes)
Base.iterate(a::EClass, state) = iterate(a.nodes, state)

Base.length(a::EClass) = length(a.nodes)

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

"""
    merge_analysis_data!(a::EClass{D}, b::EClass{D})::Tuple{Bool,Bool,Union{D,Nothing}} where {D}

This is an internal function and should not be called directly by users; this
docstring is only for those who wish to understand Metatheory internals.

Returns a tuple of: `(did_update_a, did_update_b, newdata)` where:

- `did_update_a` is a boolean indicating whether `a`'s analysis class was updated
- `did_update_b` is a boolean indicating whether `b`'s analysis class was updated
- `newdata` is the merged analysis data
"""
function merge_analysis_data!(a::EClass{D}, b::EClass{D})::Tuple{Bool,Bool,Union{D,Nothing}} where {D}
  if !isnothing(a.data) && !isnothing(b.data)
    new_a_data = join(a.data, b.data)
    (a.data != new_a_data, b.data != new_a_data, new_a_data)
  elseif isnothing(a.data) && !isnothing(b.data)
    # a merged, b not merged
    (true, false, b.data)
  elseif !isnothing(a.data) && isnothing(b.data)
    (false, true, a.data)
  else
    (false, false, nothing)
  end
end

"""
There's no need of computing hash for dictionaries where keys are UInt64.
Wrap them in an immutable struct that overrides `hash`.

TODO: this is rather hacky. We need a more performant dict implementation.

Trick from: https://discourse.julialang.org/t/dictionary-with-custom-hash-function/49168
"""
struct IdKey
  val::Id
end

"""
Recall that `Base.hash` combines an existing "seed" (h) with a new value (a).

In this case, we just use bitwise XOR; very cheap! This is because
[`IdKey`](@ref) is supposed to just hash to itself, so we don't need to do
anything special to `a.val`.
"""
Base.hash(a::IdKey, h::UInt) = xor(a.val, h)

Base.:(==)(a::IdKey, b::IdKey) = a.val == b.val

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
for implementation details. Of special notice is the e-graph invariants,
and when they do or do not hold. One of the main innovations of `egg` was to
"batch" the maintenance of the e-graph invariants. We use the `clean` field
on this struct to keep track of whether there is pending work to do in order
to re-establish the e-graph invariants.
"""
mutable struct EGraph{ExpressionType,Analysis}
  """
  stores the equality relations over e-class ids

  More specifically, the `(potentially non-root id) --> (root id)` mapping.
  """
  uf::UnionFind

  """
  map from eclass id to eclasses

  The `(root id) --> e-class` mapping.
  """
  classes::Dict{IdKey,EClass{Analysis}}

  """
  hashcons mapping e-nodes to their e-class id

  The `e-node --> (potentially non-root id)` mapping.
  """
  memo::Dict{VecExpr,Id}

  """
  hashcons the constants in the e-graph

  For performance reasons, the "head" of an e-node is stored in the e-node as a
  hash (so that it fits in a flat vector of unsigned integers
  ([`VecExpr`](@ref))) and this dictionary is used to get the actual Julia
  object of the head when extracting terms.
  """
  constants::Dict{UInt64,Any}

  """
  Nodes which need to be processed for rebuilding. The id is the id of the enode, not the canonical id of the eclass.
  """
  pending::Vector{Pair{VecExpr,Id}}

  """
  When an e-node is added to an e-graph for the first time, we add analysis data to the
  newly-created e-class by calling [`EGraphs.make`](@ref) on the head of the e-node and the analysis
  data for the arguments to that e-node. However, the analysis data for the arguments to
  that e-node could get updated at some point, as e-classes are merged.

  This is a queue for e-nodes which have had the analysis of some of their arguments
  updated, but have not updated the analysis of their parent e-class yet.
  """
  analysis_pending::UniqueQueue{Pair{VecExpr,Id}}

  """
  The Id of the e-class that we have built this e-graph to simplify.
  """
  root::Id

  "a cache mapping signatures (function symbols and their arity) to e-classes that contain e-nodes with that function symbol."
  classes_by_op::Dict{IdKey,Vector{Id}}

  "do we need to do extra work in order to re-establish the e-graph invariants"
  clean::Bool

  "If we use global buffers we may need to lock. Defaults to false."
  needslock::Bool
  lock::ReentrantLock
end


"""
    EGraph(expr)
Construct an EGraph from a starting symbolic expression `expr`.
"""
function EGraph{ExpressionType,Analysis}(; needslock::Bool = false) where {ExpressionType,Analysis}
  EGraph{ExpressionType,Analysis}(
    UnionFind(),
    Dict{IdKey,EClass{Analysis}}(),
    Dict{VecExpr,Id}(),
    Dict{UInt64,Any}(),
    Pair{VecExpr,Id}[],
    UniqueQueue{Pair{VecExpr,Id}}(),
    0,
    Dict{IdKey,Vector{Id}}(),
    false,
    needslock,
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

@inline get_constant(@nospecialize(g::EGraph), hash::UInt64) = g.constants[hash]
@inline has_constant(@nospecialize(g::EGraph), hash::UInt64)::Bool = haskey(g.constants, hash)

@inline needs_operation_quoting(g::EGraph) = false
@inline needs_operation_quoting(g::EGraph{Expr}) = true

# Why does one of these use `get!` and the other use `setindex!`?

@inline function add_constant!(@nospecialize(g::EGraph), @nospecialize(c))::Id
  h = hash(c)
  get!(g.constants, h, c)
  h
end

@inline function add_constant_hashed!(@nospecialize(g::EGraph), @nospecialize(c), h::UInt64)::Id
  g.constants[h] = c
  h
end


function to_expr(g::EGraph, n::VecExpr)
  v_isexpr(n) || return get_constant(g, v_head(n))
  h = get_constant(g, v_head(n))
  args = Core.SSAValue.(Int.(v_children(n)))
  if v_iscall(n)
    maketerm(Expr, :call, [h; args], nothing)
  else
    maketerm(Expr, h, args, nothing)
  end
end

function pretty_dict(g::EGraph)
  d = Dict{Int,Vector{Any}}()
  for (class_id, eclass) in g.classes
    d[class_id.val] = map(n -> to_expr(g, n), eclass.nodes)
  end
  d
end
export pretty_dict

function Base.show(io::IO, g::EGraph)
  d = pretty_dict(g)
  t = "$(typeof(g)) with $(length(d)) e-classes:"
  cs = map(sort!(collect(d); by = first)) do (k, vect)
    "  $k => [$(Base.join(vect, ", "))]"
  end
  print(io, Base.join([t; cs], "\n"))
end


"""
Returns the canonical e-class id for a given e-class.
"""
@inline find(g::EGraph, a::Id)::Id = find(g.uf, a)
@inline find(@nospecialize(g::EGraph), @nospecialize(a::EClass))::Id = find(g, a.id)

@inline Base.getindex(g::EGraph, i::Id) = g.classes[IdKey(find(g, i))]

"""
Make sure all of the arguments of `n` point to root nodes in the unionfind
data structure for `g`.
"""
function canonicalize!(g::EGraph, n::VecExpr)
  if v_isexpr(n)
    for i in (VECEXPR_META_LENGTH + 1):length(n)
      @inbounds n[i] = find(g, n[i])
    end
    v_unset_hash!(n)
  end
  v_hash!(n)
  n
end

function lookup(g::EGraph, n::VecExpr)::Id
  canonicalize!(g, n)

  id = get(g.memo, n, zero(Id))
  iszero(id) ? id : find(g, id)
end


function add_class_by_op(g::EGraph, n, eclass_id)
  key = IdKey(v_signature(n))
  vec = get!(g.classes_by_op, key, Vector{Id}())
  push!(vec, eclass_id)
end

"""
Inserts an e-node in an [`EGraph`](@ref)
"""
function add!(g::EGraph{ExpressionType,Analysis}, n::VecExpr, should_copy::Bool)::Id where {ExpressionType,Analysis}
  canonicalize!(g, n)

  id = get(g.memo, n, zero(Id))
  iszero(id) || return id

  if should_copy
    n = copy(n)
  end

  id = push!(g.uf) # create new singleton eclass

  if v_isexpr(n)
    for c_id in v_children(n)
      addparent!(g.classes[IdKey(c_id)], n, id)
    end
  end

  g.memo[n] = id

  add_class_by_op(g, n, id)
  eclass = EClass{Analysis}(id, VecExpr[copy(n)], Pair{VecExpr,Id}[], make(g, n))
  g.classes[IdKey(id)] = eclass
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

  isexpr(e) || return add!(g, VecExpr(Id[Id(0), Id(0), Id(0), add_constant!(g, e)]), false)

  args = iscall(e) ? arguments(e) : children(e)
  ar = length(args)
  n = v_new(ar)
  v_set_flag!(n, VECEXPR_FLAG_ISTREE)
  iscall(e) && v_set_flag!(n, VECEXPR_FLAG_ISCALL)
  h = iscall(e) ? operation(e) : head(e)
  v_set_head!(n, add_constant!(g, h))
  # get the signature from op and arity
  v_set_signature!(n, hash(maybe_quote_operation(h), hash(ar)))
  for i in v_children_range(n)
    @inbounds n[i] = addexpr!(g, args[i - VECEXPR_META_LENGTH])
  end

  add!(g, n, false)
end

"""
Given an [`EGraph`](@ref) and two e-class ids, merge the two corresponding e-classes.

This includes merging the analysis data of the e-classes.
"""
function Base.union!(
  g::EGraph{ExpressionType,AnalysisType},
  enode_id1::Id,
  enode_id2::Id,
)::Bool where {ExpressionType,AnalysisType}
  g.clean = false

  id_1 = IdKey(find(g, enode_id1))
  id_2 = IdKey(find(g, enode_id2))

  id_1 == id_2 && return false

  # Make sure class 2 has fewer parents
  if length(g.classes[id_1].parents) < length(g.classes[id_2].parents)
    id_1, id_2 = id_2, id_1
  end

  union!(g.uf, id_1.val, id_2.val)

  eclass_2 = pop!(g.classes, id_2)::EClass
  eclass_1 = g.classes[id_1]::EClass

  append!(g.pending, eclass_2.parents)

  (merged_1, merged_2, new_data) = merge_analysis_data!(eclass_1, eclass_2)
  merged_1 && append!(g.analysis_pending, eclass_1.parents)
  merged_2 && append!(g.analysis_pending, eclass_2.parents)


  # update eclass_1
  append!(eclass_1.nodes, eclass_2.nodes)
  append!(eclass_1.parents, eclass_2.parents)
  eclass_1.data = new_data

  modify!(g, eclass_1)

  return true
end

"""
Returns whether all of `ids...` are the same e-class in `g`.
"""
function in_same_class(g::EGraph, ids::Id...)::Bool
  nids = length(ids)
  nids == 1 && return true

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

  for (eclass_id, eclass) in g.classes
    # old_len = length(eclass.nodes)
    for n in eclass.nodes
      canonicalize!(g, n)
    end
    # Sort to go in order?
    unique!(eclass.nodes)

    for n in eclass.nodes
      add_class_by_op(g, n, eclass_id.val)
    end
  end

  for v in values(g.classes_by_op)
    sort!(v)
    unique!(v)
  end
end

function process_unions!(g::EGraph{ExpressionType,AnalysisType})::Int where {ExpressionType,AnalysisType}
  n_unions = 0

  while !isempty(g.pending) || !isempty(g.analysis_pending)
    while !isempty(g.pending)
      (node::VecExpr, eclass_id::Id) = pop!(g.pending)
      node = copy(node)
      canonicalize!(g, node)
      old_class_id = get!(g.memo, node, eclass_id)
      if old_class_id != eclass_id
        did_something = union!(g, old_class_id, eclass_id)
        # TODO unique! can node dedup be moved here? compare performance
        # did_something && unique!(g[eclass_id].nodes)
        n_unions += did_something
      end
    end

    while !isempty(g.analysis_pending)
      (node::VecExpr, eclass_id::Id) = pop!(g.analysis_pending)
      eclass_id = find(g, eclass_id)
      eclass_id_key = IdKey(eclass_id)
      eclass = g.classes[eclass_id_key]

      node_data = make(g, node)
      if !isnothing(node_data)
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
          append!(g.analysis_pending, eclass.parents)
        end
      end
    end
  end
  n_unions
end

function check_memo(g::EGraph)::Bool
  test_memo = Dict{VecExpr,Id}()
  for (id, class) in g.classes
    @assert id.val == class.id
    for node in class.nodes
      old_id = get!(test_memo, node, id.val)
      if old_id != id.val
        @assert find(g, old_id) == find(g, id.val) "Unexpected equivalence $node $(g[find(g, id.val)].nodes) $(g[find(g, old_id)].nodes)"
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
function rebuild!(g::EGraph; should_check_memo = false, should_check_analysis = false)
  n_unions = process_unions!(g)
  trimmed_nodes = rebuild_classes!(g)
  @assert !should_check_memo || check_memo(g)
  @assert !should_check_analysis || check_analysis(g)
  g.clean = true

  @debug "REBUILT" n_unions trimmed_nodes
end

# Thanks to Max Willsey and Yihong Zhang

"""
Given a ground pattern, which is a pattern that has no pattern variables, find
the eclass id in the egraph that represents that ground pattern.
"""
function lookup_pat(g::EGraph{ExpressionType}, p::Pat)::Id where {ExpressionType}
  if p.type === PAT_LITERAL
    # TODO avoid using enode vector for lookup, just try using hash
    return has_constant(g, p.head_hash) ? lookup(g, p.n) : 0
  end
  @assert p.type === PAT_EXPR && p.isground

  args = children(p)
  h = v_head(p.n)

  has_op = has_constant(g, h) || (h != p.name_hash && has_constant(g, p.name_hash))
  has_op || return 0

  for i in v_children_range(p.n)
    @inbounds p.n[i] = lookup_pat(g, args[i - VECEXPR_META_LENGTH])
    p.n[i] <= 0 && return 0
  end

  id = lookup(g, p.n)
  if id <= 0 && h != p.name_hash
    v_set_head!(p.n, p.name_hash)
    id = lookup(g, p.n)
    v_set_head!(p.n, p.head_hash)
  end
  id
end

