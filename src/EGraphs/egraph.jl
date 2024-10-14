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
  parents::Vector{Pair{VecExpr,Id}} # the (canoncial) parent node and the parent eclass id holding the node
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
for implementation details.
"""
mutable struct EGraph{ExpressionType,Analysis}
  "stores the equality relations over e-class ids"
  uf::UnionFind
  "map from eclass id to eclasses"
  classes::Dict{IdKey,EClass{Analysis}}
  "vector of all e-nodes (canonicalized), index is enode id, may hold duplicates after canonicalization."
  nodes::Vector{VecExpr}
  "hashcons mapping e-nodes to their e-class id"
  memo::Dict{VecExpr,Id}
  "Hashcons the constants in the e-graph"
  constants::Dict{UInt64,Any}
  "E-classes whose parent nodes have to be reprocessed."
  pending::Vector{Id}
  "E-class whose parent nodes have to be reprocessed."
  analysis_pending::Vector{Id}
  root::Id
  "a cache mapping signatures (function symbols and their arity) to e-classes that contain e-nodes with that function symbol."
  classes_by_op::Dict{IdKey,Vector{Id}}
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
    Vector{VecExpr}(),
    Dict{VecExpr,Id}(),
    Dict{UInt64,Any}(),
    Vector{Id}(),
    Vector{Id}(),
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
  d = Dict{Int,Tuple{Vector{Any},Vector{Any}}}()
  for (class_id, eclass) in g.classes
    d[class_id.val] = (map(n -> to_expr(g, n), eclass.nodes), map(pair -> to_expr(g, pair[1]) => Int(pair[2]), eclass.parents))
  end
  d
end
export pretty_dict

function Base.show(io::IO, g::EGraph)
  d = pretty_dict(g)
  t = "$(typeof(g)) with $(length(d)) e-classes:"
  cs = map(sort!(collect(d); by = first)) do (k, (nodes, parents))
    "  $k => [$(Base.join(nodes, ", "))] parents: [$(Base.join(parents, ", "))]"
  end
  print(io, Base.join([t; cs], "\n"))
end


"""
Returns the canonical e-class id for a given e-class.
"""
@inline find(g::EGraph, a::Id)::Id = find(g.uf, a)
@inline find(@nospecialize(g::EGraph), @nospecialize(a::EClass))::Id = find(g, a.id)

@inline Base.getindex(g::EGraph, i::Id) = g.classes[IdKey(find(g, i))]

function canonicalize!(g::EGraph, n::VecExpr)
  v_isexpr(n) || @goto ret
  for i in (VECEXPR_META_LENGTH + 1):length(n)
    @inbounds n[i] = find(g, n[i])
  end
  v_unset_hash!(n)
  @label ret
  v_hash!(n)
  n
end

function lookup(g::EGraph, n::VecExpr)::Id
  canonicalize!(g, n)

  id = get(g.memo, n, zero(Id))
  iszero(id) ? id : find(g, id) # find necessary because g.memo is not necessarily canonical
end


function add_class_by_op(g::EGraph, n, eclass_id)
  key = IdKey(v_signature(n))
  vec = get!(Vector{Id}, g.classes_by_op, key)
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
  push!(g.nodes, n)

  # g.nodes, eclass.nodes, eclass.parents, and g.memo all have a reference to the same VecExpr for the new enode
  # the node must never be manipulated while it is contained in memo
  
  if v_isexpr(n)
    for c_id in v_children(n)
      push!(g.classes[IdKey(c_id)].parents, n => id)
    end
  end

  g.memo[n] = id

  add_class_by_op(g, n, id)
  eclass = EClass{Analysis}(id, VecExpr[n], Id[], make(g, n))
  g.classes[IdKey(id)] = eclass
  modify!(g, eclass)

  # push!(g.pending, id) #  We just created a new eclass for a new node. No need to reprocess parents (TODO: check)

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

addexpr!(::EGraph, se::EClass) = se.id # TODO: why do we need this?

"""
Recursively traverse an type satisfying the `TermInterface` and insert terms into an
[`EGraph`](@ref). If `e` has no children (has an arity of 0) then directly
insert the literal into the [`EGraph`](@ref).
"""
function addexpr!(g::EGraph, se)::Id
  e = preprocess(se) # TODO: type stability issue?

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
Given an [`EGraph`](@ref) and two e-class ids, set
the two e-classes as equal.
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

  merged_id = union!(g.uf, id_1.val, id_2.val)

  eclass_2 = pop!(g.classes, id_2)::EClass
  eclass_1 = g.classes[id_1]::EClass

  push!(g.pending, merged_id) 
  # push!(g.pending, id_2.val) # TODO: sufficient?

  (merged_1, merged_2, new_data) = merge_analysis_data!(eclass_1, eclass_2)
  merged_1 && push!(g.analysis_pending, id_1.val)
  merged_2 && push!(g.analysis_pending, id_2.val)


  # update eclass_1
  append!(eclass_1.nodes, eclass_2.nodes)
  append!(eclass_1.parents, eclass_2.parents)
  eclass_1.data = new_data

  modify!(g, eclass_1)

  return true
end

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

  trimmed_nodes = 0
  for (eclass_id, eclass) in g.classes
    # for n in eclass.nodes
    #   memo_class = pop!(g.memo, n, 0)
    #   canonicalize!(g, n)
    #   g.memo[n] = eclass_id.val
    # end
    # TODO Sort to go in order?
    trimmed_nodes += length(eclass.nodes)
    unique!(eclass.nodes)
    trimmed_nodes -= length(eclass.nodes)

    for n in eclass.nodes
      add_class_by_op(g, n, eclass_id.val)
    end
  end

  for v in values(g.classes_by_op)
    sort!(v)
    unique!(v) # TODO: _groupedunique!(itr), and implement isless(a::VecExpr, b::VecExpr)
  end
  trimmed_nodes
end

function process_unions!(g::EGraph{ExpressionType,AnalysisType})::Int where {ExpressionType,AnalysisType}
  n_unions = 0

  while !isempty(g.pending) || !isempty(g.analysis_pending)
    # while !isempty(g.pending)
      # TODO: is it useful to deduplicate here? check perf
      todo = collect(unique(id -> find(g, id), g.pending))
      @debug "Worklist reduced from $(length(g.pending)) to $(length(todo)) entries."
      empty!(g.pending)
      
      for id in todo
        n_unions += repair_parents!(g, id)
      end
    #end

    #while !isempty(g.analysis_pending)
      # TODO: is it useful to deduplicate here? check perf
      todo = collect(unique(id -> find(g, id), g.analysis_pending))
      @debug "Analysis worklist reduced from $(length(g.analysis_pending)) to $(length(todo)) entries."
      empty!(g.analysis_pending)

      for id in todo
        update_analysis_upwards!(g, id)
      end
    #end
  end
  n_unions
end

function repair_parents!(g::EGraph, id::Id)
  n_unions = 0
  eclass = g[id] # id does not have to be an eclass id anymore if we merged classes below
  for (p_node, _) in eclass.parents
    # @assert haskey(g.memo, p_node) "eclass: $(Int(id))\n parent: $p_node => $p_eclass \n$g"
    memo_class = pop!(g.memo, p_node, 0)  # TODO: could we be messy instead and just canonicalize the node and add again (without pop!)?
    
    if memo_class > 0
      canonicalize!(g, p_node)
      memo_class = find(g, memo_class)
      # @show "new",p_node,memo_class
      g.memo[p_node] = memo_class
    end
    # merge is done below
    # # if duplicate enodes occur after canonicalization we detect this here and union the eclasses
    # if memo_class != p_eclass
    #   did_something = union!(g, memo_class, p_eclass)
    #   # TODO unique! can node dedup be moved here? compare performance
    #   # did_something && unique!(g[eclass_id].nodes)
    #   n_unions += did_something
    # end
  end

  # TODO: sort first? 
  # unique!(pair -> pair[1], eclass.parents)
  
  # sort and delete duplicate nodes last to first
  if !isempty(eclass.parents) 
    new_parents = Vector{Pair{VecExpr,Id}}()
    sort!(eclass.parents, by=pair->pair[1])
    (prev_node, prev_id) = first(eclass.parents)
    
    if prev_id != find(g, prev_id) 
      n_unions += 1
      union!(g, prev_id, find(g, prev_id)) 
    end
      
    prev_id = find(g, prev_id)
    push!(new_parents, prev_node => prev_id)
    
    for i in Iterators.drop(eachindex(eclass.parents), 1)
      (cur_node, cur_id) = eclass.parents[i]
      
      if cur_node == prev_node  # could check hash(cur_node) == hash(prev_node) first
        if union!(g, cur_id, prev_id) 
          n_unions += 1
        end
      else
        cur_id = find(g, cur_id)
        push!(new_parents, cur_node => cur_id)
        prev_node, prev_id = cur_node, cur_id
      end
    end
    
    # TODO: remove assertions
    @assert length(unique(pair -> pair[1], new_parents)) == length(new_parents)  "not unique: $new_parents"
    # @assert all(pair -> pair[2] == find(g, pair[2]), new_parents)  "not refering to eclasses: $(new_parents)\n $g"
    
    eclass.parents = new_parents
  end
  n_unions
end
function update_analysis_upwards!(g::EGraph, id::Id)
  for (p_node, p_id) in g.classes[IdKey(id)]
    p_id = find(g, p_id)
    eclass = g.classes[IdKey(p_id)]

    node_data = make(g, p_node)
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

function check_parents(g::EGraph)::Bool
  for (id, class) in g.classes
    # make sure that the parent node and parent eclass occurs in the parents vector for all children
    for n in class.nodes
      for chd_id in v_children(n)
        chd_class = g[chd_id]
        any(nid -> canonicalize!(g, copy(g.nodes[nid])) == n, chd_class.parents) || error("parent node is missing from child_class.parents")
        any(nid -> find(g, nid) == id.val, chd_class.parents) || error("missing parent reference from child")
      end
    end

    # make sure all nodes and parent ids occuring in the parent vector have this eclass as a child
    for nid in class.parents
      parent_class = g[nid]
      any(n -> any(ch -> ch == id.val, v_children(n)), parent_class.nodes) || error("no node in the parent references the eclass") # nodes are canonicalized

      parent_node = g.nodes[nid]
      parent_node_copy = copy(parent_node)
      canonicalize!(g, parent_node_copy)
      (parent_node_copy in parent_class.nodes) || error("the node from the parent list does not occur in the parent nodes") # might fail because parent_node is probably not canonical
    end
  end

  true
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
function rebuild!(g::EGraph; should_check_parents=false, should_check_memo=false, should_check_analysis=false)
  n_unions = process_unions!(g)
  trimmed_nodes = rebuild_classes!(g)

  @assert !should_check_parents || check_parents(g)
  @assert !should_check_memo || check_memo(g)
  @assert !should_check_analysis || check_analysis(g)
  g.clean = true

  @debug "REBUILT" n_unions trimmed_nodes
end

# Thanks to Max Willsey and Yihong Zhang


function lookup_pat(g::EGraph{ExpressionType}, p::PatExpr)::Id where {ExpressionType}
  @assert isground(p)

  args = children(p)
  h = v_head(p.n)

  has_op = has_constant(g, h) || (h != p.quoted_head_hash && has_constant(g, p.quoted_head_hash))
  has_op || return 0

  for i in v_children_range(p.n)
    @inbounds p.n[i] = lookup_pat(g, args[i - VECEXPR_META_LENGTH])
    p.n[i] <= 0 && return 0
  end

  id = lookup(g, p.n)
  if id <= 0 && h != p.quoted_head_hash
    v_set_head!(p.n, p.quoted_head_hash)
    id = lookup(g, p.n)
    v_set_head!(p.n, p.head_hash)
  end
  id
end

function lookup_pat(g::EGraph, p::PatLiteral)::Id
  h = last(p.n)
  has_constant(g, h) ? lookup(g, p.n) : 0
end
