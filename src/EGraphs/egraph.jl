# Functional implementation of https://egraphs-good.github.io/
# https://dl.acm.org/doi/10.1145/3434304


# abstract type AbstractENode end

const AnalysisData = NamedTuple{N,T} where {N,T<:Tuple}
const EClassId = Int64
const TermTypes = Dict{Tuple{Any,Int},Type}
const UNDEF_ARGS = Vector{EClassId}(undef, 0)

struct ENode
  # TODO use UInt flags
  istree::Bool
  # E-graph contains mappings from the UInt id of head, operation and symtype to their original value
  exprhead::Any
  operation::Any
  symtype::Any
  args::Vector{EClassId}
  hash::Ref{UInt}
  ENode(exprhead, operation, symtype, args) = new(true, exprhead, operation, symtype, args, Ref{UInt}(0))
  ENode(literal) = new(false, nothing, literal, nothing, UNDEF_ARGS, Ref{UInt}(0))
end

TermInterface.istree(n::ENode) = n.istree
TermInterface.symtype(n::ENode) = n.symtype
TermInterface.exprhead(n::ENode) = n.exprhead
TermInterface.operation(n::ENode) = n.operation
TermInterface.arguments(n::ENode) = n.args
TermInterface.arity(n::ENode) = length(n.args)


# This optimization comes from SymbolicUtils
# The hash of an enode is cached to avoid recomputing it.
# Shaves off a lot of time in accessing dictionaries with ENodes as keys.
function Base.hash(n::ENode, salt::UInt)
  !iszero(salt) && return hash(hash(n, zero(UInt)), salt)
  h = n.hash[]
  !iszero(h) && return h
  h′ = hash(n.args, hash(n.exprhead, hash(n.operation, hash(n.istree, salt))))
  n.hash[] = h′
  return h′
end

function Base.:(==)(a::ENode, b::ENode)
  hash(a) == hash(b) && a.operation == b.operation
end

function toexpr(n::ENode)
  n.istree || return n.operation
  Expr(:call, :ENode, exprhead(n), operation(n), symtype(n), arguments(n))
end

Base.show(io::IO, x::ENode) = print(io, toexpr(x))

op_key(n::ENode) = (operation(n) => istree(n) ? -1 : arity(n))

# parametrize metadata by M
mutable struct EClass
  g # EGraph
  id::EClassId
  nodes::Vector{ENode}
  parents::Vector{Pair{ENode,EClassId}}
  data::AnalysisData
end

EClass(g, id) = EClass(g, id, ENode[], Pair{ENode,EClassId}[], nothing)
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

function addparent!(a::EClass, n::ENode, id::EClassId)
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
  uf::IntDisjointSet
  "map from eclass id to eclasses"
  classes::Dict{EClassId,EClass}
  "hashcons"
  memo::Dict{ENode,EClassId}             # memo
  "worklist for ammortized upwards merging"
  dirty::Vector{EClassId}
  root::EClassId
  "A vector of analyses associated to the EGraph"
  analyses::Dict{Union{Symbol,Function},Union{Symbol,Function}}
  "a cache mapping function symbols and their arity to e-classes that contain e-nodes with that function symbol."
  classes_by_op::Dict{Pair{Any,Int},Vector{EClassId}}
  default_termtype::Type
  termtypes::TermTypes
  numclasses::Int
  numnodes::Int
end


"""
    EGraph(expr)
Construct an EGraph from a starting symbolic expression `expr`.
"""
function EGraph()
  EGraph(
    IntDisjointSet(),
    Dict{EClassId,EClass}(),
    Dict{ENode,EClassId}(),
    EClassId[],
    -1,
    Dict{Union{Symbol,Function},Union{Symbol,Function}}(),
    Dict{Any,Vector{EClassId}}(),
    Expr,
    TermTypes(),
    0,
    0,
    # 0
  )
end

function EGraph(e; keepmeta = false)
  g = EGraph()
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

function settermtype!(g::EGraph, f, ar, T)
  g.termtypes[(f, ar)] = T
end

function settermtype!(g::EGraph, T)
  g.default_termtype = T
end

function gettermtype(g::EGraph, f, ar)
  if haskey(g.termtypes, (f, ar))
    g.termtypes[(f, ar)]
  else
    g.default_termtype
  end
end


"""
Returns the canonical e-class id for a given e-class.
"""
find(g::EGraph, a::EClassId)::EClassId = find_root(g.uf, a)
find(g::EGraph, a::EClass)::EClassId = find(g, a.id)

Base.getindex(g::EGraph, i::EClassId) = g.classes[find(g, i)]

### Definition 2.3: canonicalization
iscanonical(g::EGraph, n::ENode) = !n.istree || n == canonicalize(g, n)
iscanonical(g::EGraph, e::EClass) = find(g, e.id) == e.id

function canonicalize(g::EGraph, n::ENode)::ENode
  n.istree || return n
  ar = length(n.args)
  ar == 0 && return n
  canonicalized_args = Vector{EClassId}(undef, ar)
  for i in 1:ar
    @inbounds canonicalized_args[i] = find(g, n.args[i])
  end
  ENode(exprhead(n), operation(n), symtype(n), canonicalized_args)
end

function canonicalize!(g::EGraph, n::ENode)
  n.istree || return n
  for (i, arg) in enumerate(n.args)
    @inbounds n.args[i] = find(g, arg)
  end
  n.hash[] = UInt(0)
  return n
end


function canonicalize!(g::EGraph, e::EClass)
  e.id = find(g, e.id)
end

function lookup(g::EGraph, n::ENode)::EClassId
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
function add!(g::EGraph, n::ENode)::EClassId
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
  classdata = EClass(g, id, ENode[n], Pair{ENode,EClassId}[])
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
Recursively traverse an type satisfying the `TermInterface` and insert terms into an
[`EGraph`](@ref). If `e` has no children (has an arity of 0) then directly
insert the literal into the [`EGraph`](@ref).
"""
function addexpr!(g::EGraph, se, keepmeta = false)::EClassId
  e = preprocess(se)

  n = if istree(se)
    args = arguments(e)
    ar = length(args)
    class_ids = Vector{EClassId}(undef, ar)
    for i in 1:ar
      @inbounds class_ids[i] = addexpr!(g, args[i], keepmeta)
    end
    ENode(exprhead(e), operation(e), symtype(e), class_ids)
  else # constant enode
    ENode(e)
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

function in_same_class(g::EGraph, a, b)
  find(g, a) == find(g, b)
end


# TODO new rebuilding from egg
"""
This function restores invariants and executes
upwards merging in an [`EGraph`](@ref). See
the [egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304)
for more details.
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

function rebuild_classes!(g::EGraph)
  @show g.classes_by_op
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
      add_class_by_op(g, n, id)
    end
  end

  for v in values(g.classes_by_op)
    unique!(v)
  end
end

function process_unions!(g::EGraph)

end

function repair!(g::EGraph, id::EClassId)
  id = find(g, id)
  ecdata = g[id]
  ecdata.id = id

  new_parents = (length(ecdata.parents) > 30 ? OrderedDict : LittleDict){ENode,EClassId}()

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


  function reachable_node(xn::ENode)
    xn.istree || return
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


"""
When extracting symbolic expressions from an e-graph, we need 
to instruct the e-graph how to rebuild expressions of a certain type. 
This function must be extended by the user to add new types of expressions that can be manipulated by e-graphs.
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
    id = lookup(g, ENode(eh, op, T, ids))
    id < 0 ? lookup(g, ENode(eh, nameof(op), T, ids)) : id
  else
    lookup(g, ENode(eh, op, T, ids))
  end
end

lookup_pat(g::EGraph, p::Any) = lookup(g, ENode(p))
lookup_pat(g::EGraph, p::AbstractPat) = throw(UnsupportedPatternException(p))
