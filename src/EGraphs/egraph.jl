# Functional implementation of https://egraphs-good.github.io/
# https://dl.acm.org/doi/10.1145/3434304


"""
    AbstractENode

Abstract supertype for the nodes stored in an [`EGraph`](@ref).

Concrete node types must be hashable and comparable. Tree nodes should provide
the TermInterface methods `istree`, `operation`, `arguments`, `arity`, and
`symtype`; literal nodes should report `istree(node) == false`.
"""
abstract type AbstractENode end

import Metatheory: maybelock!
import TermInterface

const AnalysisData = NamedTuple{N,T} where {N,T<:Tuple}
"""
    EClassId

Integer type used to identify e-classes inside an [`EGraph`](@ref).
"""
const EClassId = Int64
const TermTypes = Dict{Tuple{Any,Int},Type}
# TODO document bindings
const Bindings = Base.ImmutableDict{Int,Tuple{Int,Int}}
const DEFAULT_BUFFER_SIZE = 1048576

"""
    ENodeLiteral(value)

Represent a literal value as an e-node.

# Fields

- `value`: Literal stored in the e-graph.

Literal nodes are leaves: `TermInterface.istree(node)` is `false` and
`operation(node)` returns `value`.
"""
struct ENodeLiteral <: AbstractENode
  value
  hash::Ref{UInt}
  ENodeLiteral(a) = new(a, Ref{UInt}(0))
end

Base.:(==)(a::ENodeLiteral, b::ENodeLiteral) = hash(a) == hash(b)

TermInterface.istree(n::ENodeLiteral) = false
TermInterface.exprhead(n::ENodeLiteral) = nothing
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


"""
    ENodeTerm(exprhead, operation, symtype, class_ids)

Represent a compound term whose children are e-class identifiers.

# Arguments

- `exprhead`: Expression head, such as `:call`.
- `operation`: Function or operator represented by the node.
- `symtype`: Symbolic result type.
- `class_ids`: Vector of child [`EClassId`](@ref)s.

# Fields

- `exprhead`, `operation`, `symtype`, `args`: TermInterface data.
- `hash`: Mutable hash cache; callers should not mutate it directly.
"""
mutable struct ENodeTerm <: AbstractENode
  exprhead::Union{Symbol,Nothing}
  operation::Any
  symtype::Type
  args::Vector{EClassId}
  hash::Ref{UInt} # hash cache
  ENodeTerm(exprhead, operation, symtype, c_ids) = new(exprhead, operation, symtype, c_ids, Ref{UInt}(0))
end


function Base.:(==)(a::ENodeTerm, b::ENodeTerm)
  hash(a) == hash(b) && a.operation == b.operation
end


TermInterface.istree(n::ENodeTerm) = true
TermInterface.symtype(n::ENodeTerm) = n.symtype
TermInterface.exprhead(n::ENodeTerm) = n.exprhead
TermInterface.operation(n::ENodeTerm) = n.operation
TermInterface.arguments(n::ENodeTerm) = n.args
TermInterface.arity(n::ENodeTerm) = length(n.args)

# This optimization comes from SymbolicUtils
# The hash of an enode is cached to avoid recomputing it.
# Shaves off a lot of time in accessing dictionaries with ENodes as keys.
function Base.hash(t::ENodeTerm, salt::UInt)
  !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
  h = t.hash[]
  !iszero(h) && return h
  h′ = hash(t.args, hash(t.exprhead, hash(t.operation, salt)))
  t.hash[] = h′
  return h′
end


# parametrize metadata by M
"""
    EClass(g, id, nodes, parents, data)

Store all equivalent e-nodes and analysis data for one e-class.

# Fields

- `g`: Owning [`EGraph`](@ref).
- `id`: Canonical [`EClassId`](@ref).
- `nodes`: E-nodes in this equivalence class.
- `parents`: Parent e-nodes and their e-class identifiers.
- `data`: Named tuple of analysis references.

Use `EClass(g, id)` for an empty class associated with `g`; the shorter
constructor initializes the node and parent collections.
"""
mutable struct EClass
  g # EGraph
  id::EClassId
  nodes::Vector{AbstractENode}
  parents::Vector{Pair{AbstractENode,EClassId}}
  data::AnalysisData
end

function toexpr(n::ENodeTerm)
  Expr(:call, :ENode, exprhead(n), operation(n), symtype(n), arguments(n))
end

function Base.show(io::IO, x::ENodeTerm)
  print(io, toexpr(x))
end

toexpr(n::ENodeLiteral) = operation(n)

Base.show(io::IO, x::ENodeLiteral) = print(io, toexpr(x))

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
  # print(io, a.data)
  print(io, ")")
end

function addparent!(a::EClass, n::AbstractENode, id::EClassId)
  push!(a.parents, (n => id))
end

function Base.union!(to::EClass, from::EClass)
  # TODO revisit
  append!(to.nodes, from.nodes)
  append!(to.parents, from.parents)
  if !isnothing(to.data) && !isnothing(from.data)
    to.data = join_analysis_data!(to.g, something(to.data), something(from.data))
  elseif to.data === nothing
    to.data = from.data
  end
  return to
end

function join_analysis_data!(g, dst::AnalysisData, src::AnalysisData)
  new_dst = merge(dst, src)
  for analysis_name in keys(src)
    analysis_ref = g.analyses[analysis_name]
    if hasproperty(dst, analysis_name)
      ref = getproperty(new_dst, analysis_name)
      ref[] = join(analysis_ref, ref[], getproperty(src, analysis_name)[])
    end
  end
  new_dst
end

# Thanks to Shashi Gowda
"""
    hasdata(eclass, analysis)

Return whether `eclass` contains a value for an analysis identified by a symbol
or analysis function.
"""
hasdata(a::EClass, analysis_name::Symbol) = hasproperty(a.data, analysis_name)
hasdata(a::EClass, f::Function) = hasproperty(a.data, nameof(f))
"""
    getdata(eclass, analysis[, default])

Return the value stored for `analysis` in `eclass`. When `default` is supplied,
return it if no analysis value exists.
"""
getdata(a::EClass, analysis_name::Symbol) = getproperty(a.data, analysis_name)[]
getdata(a::EClass, f::Function) = getproperty(a.data, nameof(f))[]
getdata(a::EClass, analysis_ref::Union{Symbol,Function}, default) =
  hasdata(a, analysis_ref) ? getdata(a, analysis_ref) : default


"""
    setdata!(eclass, analysis, value)

Store `value` as the analysis result for `analysis` in `eclass`.

The value is wrapped in a mutable reference so that analysis updates do not
replace the e-class named tuple.
"""
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
    EGraph

Mutable equality graph containing e-classes, e-nodes, rewrite analyses, and
the memoization state needed to maintain congruence closure.

Use [`EGraph(expr)`](@ref) to build a graph from a term. Use the zero-argument
constructor when the graph will be populated incrementally with
[`addexpr!`](@ref).

# Fields

- `uf`: Union-find structure for canonical e-class identifiers.
- `classes`: E-class storage indexed by [`EClassId`](@ref).
- `memo`: Hash-consing table for canonical e-nodes.
- `dirty`: E-classes awaiting invariant repair.
- `root`: Root e-class identifier for the initial expression.
- `analyses`: Registered analysis functions and names.
- `symcache`: Operation-to-e-class index used by matching.
- `default_termtype`, `termtypes`: Types used to reconstruct extracted terms.
- `numclasses`, `numnodes`: Current graph size counters.
- `needslock`, `buffer`, `merges_buffer`, `lock`: Matching and merge workspaces.

See the [egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304) for the
congruence-closure design used by this implementation.
"""
mutable struct EGraph
  "stores the equality relations over e-class ids"
  uf::IntDisjointSet
  "map from eclass id to eclasses"
  classes::Dict{EClassId,EClass}
  "hashcons"
  memo::Dict{AbstractENode,EClassId}             # memo
  "worklist for ammortized upwards merging"
  dirty::Vector{EClassId}
  root::EClassId
  "A vector of analyses associated to the EGraph"
  analyses::Dict{Union{Symbol,Function},Union{Symbol,Function}}
  "a cache mapping function symbols to e-classes that contain e-nodes with that function symbol."
  symcache::Dict{Any,Vector{EClassId}}
  default_termtype::Type
  termtypes::TermTypes
  numclasses::Int
  numnodes::Int
  "If we use global buffers we may need to lock. Defaults to true."
  needslock::Bool
  "Buffer for e-matching which defaults to a global. Use a local buffer for generated functions."
  buffer::Vector{Bindings}
  "Buffer for rule application which defaults to a global. Use a local buffer for generated functions."
  merges_buffer::Vector{Tuple{Int,Int}}
  lock::ReentrantLock
end


"""
    EGraph(; needslock=false, buffer_size=DEFAULT_BUFFER_SIZE)

Construct an empty equality graph.

# Arguments

- `needslock::Bool=false`: Use the graph's lock around shared matching and
  merge buffers.
- `buffer_size`: Initial capacity requested for matching buffers.

Use [`addexpr!`](@ref) to insert expressions after construction.
"""
function EGraph(; needslock::Bool = false, buffer_size = DEFAULT_BUFFER_SIZE)
  EGraph(
    IntDisjointSet(),
    Dict{EClassId,EClass}(),
    Dict{AbstractENode,EClassId}(),
    EClassId[],
    -1,
    Dict{Union{Symbol,Function},Union{Symbol,Function}}(),
    Dict{Any,Vector{EClassId}}(),
    Expr,
    TermTypes(),
    0,
    0,
    needslock,
    Bindings[],
    Tuple{Int,Int}[],
    ReentrantLock(),
  )
end

function maybelock!(f::Function, g::EGraph)
  g.needslock ? lock(f, g.buffer_lock) : f()
end

"""
    EGraph(expr; keepmeta=false, kwargs...)

Construct an [`EGraph`](@ref) containing `expr` and return it with `expr` as
its root e-class.

# Arguments

- `expr`: A term accepted by the `TermInterface` traversal used by
  [`addexpr!`](@ref).

# Keyword Arguments

- `keepmeta::Bool=false`: Preserve term metadata through the metadata analysis.
- `needslock`, `buffer_size`: Forwarded to the empty-graph constructor.

# Example

```julia
g = EGraph(:(x + 1))
root = g.root
g[root]
```
"""
function EGraph(e; keepmeta = false, kwargs...)
  g = EGraph(kwargs...)
  keepmeta && addanalysis!(g, :metadata_analysis)
  g.root = addexpr!(g, e; keepmeta = keepmeta)
  g
end

function addanalysis!(g::EGraph, costfun::Function)
  g.analyses[nameof(costfun)] = costfun
  g.analyses[costfun] = costfun
end

function addanalysis!(g::EGraph, analysis_name::Symbol)
  g.analyses[analysis_name] = analysis_name
end

"""
    settermtype!(g, operation, arity, type)

Register the symbolic result type used when reconstructing terms with
`operation` and `arity` in `g`.
"""
function settermtype!(g::EGraph, f, ar, T)
  g.termtypes[(f, ar)] = T
end

function settermtype!(g::EGraph, T)
  g.default_termtype = T
end

"""
    gettermtype(g, operation, arity)

Return the registered result type for a term, or `g.default_termtype` when no
specific registration exists.
"""
function gettermtype(g::EGraph, f, ar)
  if haskey(g.termtypes, (f, ar))
    g.termtypes[(f, ar)]
  else
    g.default_termtype
  end
end


"""
    find(egraph, eclass_or_id) -> EClassId

Return the canonical e-class identifier for an [`EClass`](@ref) or
[`EClassId`](@ref). The result is the representative used by the e-graph
after union-find path compression.
"""
find(g::EGraph, a::EClassId)::EClassId = find_root(g.uf, a)
find(g::EGraph, a::EClass)::EClassId = find(g, a.id)

Base.getindex(g::EGraph, i::EClassId) = g.classes[find(g, i)]

### Definition 2.3: canonicalization
iscanonical(g::EGraph, n::ENodeTerm) = n == canonicalize(g, n)
iscanonical(g::EGraph, n::ENodeLiteral) = true
iscanonical(g::EGraph, e::EClass) = find(g, e.id) == e.id

canonicalize(g::EGraph, n::ENodeLiteral) = n

function canonicalize(g::EGraph, n::ENodeTerm)
  if arity(n) > 0
    new_args = map(x -> find(g, x), n.args)
    return ENodeTerm(exprhead(n), operation(n), symtype(n), new_args)
  end
  return n
end

function canonicalize!(g::EGraph, n::ENodeTerm)
  for (i, arg) in enumerate(n.args)
    n.args[i] = find(g, arg)
  end
  n.hash[] = UInt(0)
  return n
end

canonicalize!(g::EGraph, n::ENodeLiteral) = n


function canonicalize!(g::EGraph, e::EClass)
  e.id = find(g, e.id)
end

"""
    lookup(g, node) -> EClassId

Return the e-class containing `node`, or `-1` when the canonical node is not in
`g`.
"""
function lookup(g::EGraph, n::AbstractENode)::EClassId
  cc = canonicalize(g, n)
  haskey(g.memo, cc) ? find(g, g.memo[cc]) : -1
end

"""
Inserts an e-node in an [`EGraph`](@ref)
"""
function add!(g::EGraph, n::AbstractENode)::EClassId
  n = canonicalize(g, n)
  haskey(g.memo, n) && return g.memo[n]

  id = push!(g.uf) # create new singleton eclass

  if n isa ENodeTerm
    for c_id in arguments(n)
      addparent!(g.classes[c_id], n, id)
    end
  end

  g.memo[n] = id

  if haskey(g.symcache, operation(n))
    push!(g.symcache[operation(n)], id)
  else
    g.symcache[operation(n)] = [id]
  end

  classdata = EClass(g, id, AbstractENode[n], Pair{AbstractENode,EClassId}[])
  g.classes[id] = classdata
  g.numclasses += 1

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
    addexpr!(egraph, expr; keepmeta=false) -> EClassId

Recursively traverse `expr` using `TermInterface` and insert its terms into the
[`EGraph`](@ref). A zero-arity term is inserted as an [`ENodeLiteral`](@ref);
compound terms are hash-consed as [`ENodeTerm`](@ref) values.

# Arguments

- `egraph`: Graph to mutate.
- `expr`: Term accepted by the `TermInterface` interface.

# Keyword Arguments

- `keepmeta::Bool=false`: Preserve metadata for later reconstruction.

# Returns

The e-class identifier containing the inserted expression. Calling this on an
equivalent expression returns the existing canonical class.
"""
function addexpr!(g::EGraph, se; keepmeta = false)::EClassId
  e = preprocess(se)

  id = add!(g, if istree(se)
    class_ids::Vector{EClassId} = [addexpr!(g, arg; keepmeta = keepmeta) for arg in arguments(e)]
    ENodeTerm(exprhead(e), operation(e), symtype(e), class_ids)
  else
    # constant enode
    ENodeLiteral(e)
  end)
  if keepmeta
    meta = TermInterface.metadata(e)
    !isnothing(meta) && setdata!(g.classes[id], :metadata_analysis, meta)
  end
  return id
end

function addexpr!(g::EGraph, ec::EClass; keepmeta = false)
  @assert g == ec.g
  find(g, ec.id)
end

"""
    merge!(egraph, left, right) -> EClassId

Merge the e-classes identified by `left` and `right`, preserving their
analysis data and scheduling congruence repair. The returned identifier is the
canonical representative after the union.

Call [`rebuild!`](@ref) before relying on all congruence invariants or running
matching over the result.
"""
function Base.merge!(g::EGraph, a::EClassId, b::EClassId)::EClassId
  id_a = find(g, a)
  id_b = find(g, b)


  id_a == id_b && return id_a
  to = union!(g.uf, id_a, id_b)
  from = (to == id_a) ? id_b : id_a

  push!(g.dirty, to)

  from_class = g.classes[from]
  to_class = g.classes[to]
  to_class.id = to

  # I (was) the troublesome line!
  g.classes[to] = union!(to_class, from_class)
  delete!(g.classes, from)
  g.numclasses -= 1

  return to
end

"""
    in_same_class(g, a, b) -> Bool

Return whether e-class identifiers `a` and `b` denote the same equivalence
class in `g`.
"""
function in_same_class(g::EGraph, a, b)
  find(g, a) == find(g, b)
end


# TODO new rebuilding from egg
"""
    rebuild!(egraph) -> EGraph

Restore e-graph congruence invariants after calls to [`merge!`](@ref) and
perform the pending upward merges. This is the operation that makes newly
equivalent compound terms discoverable by lookup and matching.

The graph is mutated in place and returned for convenient chaining. See the
[egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304) for the underlying
rebuild algorithm.
"""
function rebuild!(g::EGraph)
  # normalize!(g.uf)

  while !isempty(g.dirty)
    # todo = unique([find(egraph, id) for id ∈ egraph.dirty])
    todo = unique(g.dirty)
    empty!(g.dirty)
    for x in todo
      repair!(g, x)
    end
  end

  if g.root != -1
    g.root = find(g, g.root)
  end

  normalize!(g.uf)
end

function repair!(g::EGraph, id::EClassId)
  id = find(g, id)
  ecdata = g[id]
  ecdata.id = id

  new_parents = (length(ecdata.parents) > 30 ? OrderedDict : LittleDict){AbstractENode,EClassId}()

  for (p_enode, p_eclass) in ecdata.parents
    p_enode = canonicalize!(g, p_enode)
    # deduplicate parents
    if haskey(new_parents, p_enode)
      merge!(g, p_eclass, new_parents[p_enode])
    end
    n_id = find(g, p_eclass)
    g.memo[p_enode] = n_id
    new_parents[p_enode] = n_id
  end

  ecdata.parents = collect(new_parents)

  # ecdata.nodes = map(n -> canonicalize(g.uf, n), ecdata.nodes)

  # Analysis invariant maintenance
  for an in values(g.analyses)
    hasdata(ecdata, an) && modify!(an, g, id)
    for (p_enode, p_id) in ecdata.parents
      # p_eclass = find(g, p_eclass)
      p_eclass = g[p_id]
      if !islazy(an) && !hasdata(p_eclass, an)
        setdata!(p_eclass, an, make(an, g, p_enode))
      end
      if hasdata(p_eclass, an)
        p_data = getdata(p_eclass, an)

        if an !== :metadata_analysis
          new_data = join(an, p_data, make(an, g, p_enode))
          if new_data != p_data
            setdata!(p_eclass, an, new_data)
            push!(g.dirty, p_id)
          end
        end
      end
    end
  end

  unique!(ecdata.nodes)

  # ecdata.nodes = map(n -> canonicalize(g.uf, n), ecdata.nodes)

end


"""
Recursive function that traverses an [`EGraph`](@ref) and
returns a vector of all reachable e-classes from a given e-class id.
"""
function reachable(g::EGraph, id::EClassId)
  id = find(g, id)
  hist = EClassId[id]
  todo = EClassId[id]


  function reachable_node(xn::ENodeTerm)
    x = canonicalize(g, xn)
    for c_id in arguments(x)
      if c_id ∉ hist
        push!(hist, c_id)
        push!(todo, c_id)
      end
    end
  end
  function reachable_node(x::ENodeLiteral) end

  while !isempty(todo)
    curr = find(g, pop!(todo))
    for n in g.classes[curr]
      reachable_node(n)
    end
  end

  return hist
end


"""
    egraph_reconstruct_expression(T, operation, args; metadata=nothing,
        exprhead=:call)

Reconstruct an extracted expression of type `T` from an operation and its
children. Extend this function for a term type that [`extract!`](@ref) must
produce; the default methods handle `Expr` values.

# Arguments

- `T`: Target term type.
- `operation`: Operation or head stored in the e-node.
- `args`: Extracted child expressions.

# Keyword Arguments

- `metadata=nothing`: Metadata preserved by the metadata analysis.
- `exprhead=:call`: Expression head used when `T == Expr`.

# Extension rule

Define a method in the module that owns `T`, for example:

```julia
Metatheory.EGraphs.egraph_reconstruct_expression(
    ::Type{MyTerm}, op, args; metadata=nothing, exprhead=:call,
) = MyTerm(op, args)
```
"""
function egraph_reconstruct_expression(T::Type{Expr}, op, args; metadata = nothing, exprhead = :call)
  similarterm(Expr(:call, :_), op, args; metadata = metadata, exprhead = exprhead)
end

# Thanks to Max Willsey and Yihong Zhang

import Metatheory: lookup_pat

function lookup_pat(g::EGraph, p::PatTerm)::EClassId
  @assert isground(p)

  eh = exprhead(p)
  op = operation(p)
  args = arguments(p)
  ar = arity(p)

  T = gettermtype(g, op, ar)

  ids = map(x -> lookup_pat(g, x), args)
  !all((>)(0), ids) && return -1

  if T == Expr && op isa Union{Function,DataType}
    id = lookup(g, ENodeTerm(eh, op, T, ids))
    id < 0 && return lookup(g, ENodeTerm(eh, nameof(op), T, ids))
    return id
  else
    return lookup(g, ENodeTerm(eh, op, T, ids))
  end
end

lookup_pat(g::EGraph, p::Any) = lookup(g, ENodeLiteral(p))
lookup_pat(g::EGraph, p::AbstractPat) = throw(UnsupportedPatternException(p))
