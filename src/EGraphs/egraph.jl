# Functional implementation of https://egraphs-good.github.io/
# https://dl.acm.org/doi/10.1145/3434304


abstract type AbstractENode{T} end

const AnalysisData = NamedTuple{N,T} where {N,T<:Tuple{Vararg{<:Ref}}}
const EClassId = Int64
const HashCons = Dict{AbstractENode,EClassId}
const Analyses = Set{Union{Symbol,Function}}
const SymbolCache = Dict{Any,Set{EClassId}}
const TermTypes = Dict{Tuple{Any,EClassId},Type}

mutable struct ENodeLiteral{T} <: AbstractENode{T}
  value::T
  hash::Ref{UInt}
end

mutable struct ENodeTerm{T} <: AbstractENode{T}
  exprhead::Union{Symbol,Nothing}
  operation::Any
  args::Vector{EClassId}
  hash::Ref{UInt} # hash cache
end

# parametrize metadata by M
mutable struct EClass
  g # EGraph
  id::EClassId
  nodes::Vector{AbstractENode}
  parents::Vector{Pair{AbstractENode,EClassId}}
  data::AnalysisData
  # data::M
end

const ClassMem = Dict{EClassId,EClass}


function ENodeTerm{T}(exprhead, operation, c_ids) where {T}
  ENodeTerm{T}(exprhead, operation, c_ids, Ref{UInt}(0))
end


function Base.isequal(a::ENodeTerm, b::ENodeTerm)
  isequal(a.args, b.args) && isequal(a.exprhead, b.exprhead) && isequal(a.operation, b.operation)
end


TermInterface.istree(n::ENodeTerm) = true
TermInterface.exprhead(n::ENodeTerm) = n.exprhead
TermInterface.operation(n::ENodeTerm) = n.operation
TermInterface.arguments(n::ENodeTerm) = n.args
TermInterface.arity(n::ENodeTerm) = length(n.args)

# This optimization comes from SymbolicUtils
# The hash of an enode is cached to avoid recomputing it.
# Shaves off a lot of time in accessing dictionaries with ENodes as keys.
function Base.hash(t::ENodeTerm{T}, salt::UInt) where {T}
  !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
  h = t.hash[]
  !iszero(h) && return h
  h′ = hash(t.args, hash(t.exprhead, hash(t.operation, hash(T, salt))))
  t.hash[] = h′
  return h′
end


function toexpr(n::ENodeTerm)
  eh = exprhead(n)
  if isnothing(eh)
    return operation(n) # n is a constant enode
  end
  similarterm(Expr(:call, :_), operation(n), map(i -> Symbol(i, "ₑ"), arguments(n)); exprhead = exprhead(n))
end


# ==================================================
# ENode Literal
# ==================================================

TermInterface.istree(n::ENodeLiteral) = false
TermInterface.exprhead(n::ENodeLiteral) = nothing
TermInterface.operation(n::ENodeLiteral) = n.value
TermInterface.arity(n::ENodeLiteral) = 0

ENodeLiteral(a::T) where {T} = ENodeLiteral{T}(a, Ref{UInt}(0))

Base.:(==)(a::ENodeLiteral, b::ENodeLiteral) = isequal(a.value, b.value)


function Base.hash(t::ENodeLiteral{T}, salt::UInt) where {T}
  !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
  h = t.hash[]
  !iszero(h) && return h
  h′ = hash(t.value, hash(T, salt))
  t.hash[] = h′
  return h′
end


termtype(x::AbstractENode{T}) where {T} = T

toexpr(n::ENodeLiteral) = operation(n)

function Base.show(io::IO, x::ENodeTerm{T}) where {T}
  print(io, "ENode{$T}(", toexpr(x), ")")
end

Base.show(io::IO, x::ENodeLiteral) = print(io, toexpr(x))

EClass(g, id) = EClass(g, id, AbstractENode[], Pair{AbstractENode,EClassId}[], nothing)
EClass(g, id, nodes, parents) = EClass(g, id, nodes, parents, NamedTuple())

# Interface for indexing EClass
Base.getindex(a::EClass, i) = a.nodes[i]
Base.setindex!(a::EClass, v, i) = setindex!(a.nodes, v, i)
Base.firstindex(a::EClass) = firstindex(a.nodes)
Base.lastindex(a::EClass) = lastindex(a.nodes)

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

function Base.union!(to::EClass, from::EClass)
  append!(to.nodes, from.nodes)
  append!(to.parents, from.parents)
  if to.data !== nothing && from.data !== nothing
    # merge!(to.data, from.data)
    to.data = join_analysis_data!(to.data, from.data)
  elseif to.data === nothing
    to.data = from.data
  end
  return to
end

function join_analysis_data!(dst::AnalysisData, src::AnalysisData)
  new_dst = merge(dst, src)
  for (analysis_name, src_val) in zip(keys(src), src)
    if hasproperty(dst, analysis_name)
      ref = getproperty(new_dst, analysis_name)
      ref[] = join(analysis_name, ref[], src_val)
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
  """stores the equality relations over e-class ids"""
  # uf::IntDisjointSets{EClassId}
  uf::IntDisjointSet
  """map from eclass id to eclasses"""
  classes::ClassMem
  memo::HashCons             # memo
  """worklist for ammortized upwards merging"""
  dirty::Vector{EClassId}
  root::EClassId
  """A vector of analyses associated to the EGraph"""
  analyses::Analyses
  # """
  # a cache mapping function symbols to e-classes that
  # contain e-nodes with that function symbol.
  # """
  # symcache::SymbolCache
  default_termtype::Type
  termtypes::TermTypes
  numclasses::Int
  numnodes::Int
  # number of rules that have been applied
  # age::Int
end

"""
    EGraph(expr)
Construct an EGraph from a starting symbolic expression `expr`.
"""
function EGraph()
  EGraph(
    IntDisjointSet{EClassId}(),
    # IntDisjointSets{EClassId}(0),
    ClassMem(),
    HashCons(),
    # ParentMem(),
    EClassId[],
    -1,
    Analyses(),
    # SymbolCache(),
    Expr,
    TermTypes(),
    0,
    0,
    # 0
  )
end

function EGraph(e; keepmeta = false)
  g = EGraph()
  if keepmeta
    push!(g.analyses, :metadata_analysis)
  end

  rootclass, rootnode = addexpr!(g, e; keepmeta = keepmeta)
  g.root = rootclass.id
  g
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
# function find(g::EGraph, a::EClassId)::EClassId
#     find_root_if_normal(g.uf, a)
# end
function find(g::EGraph, a::EClassId)::EClassId
  find_root(g.uf, a)
end
find(g::EGraph, a::EClass)::EClassId = find(g, a.id)

function Base.getindex(g::EGraph, i::EClassId)
  id = find(g, i)
  ec = g.classes[id]
  # @show ec.id id a
  # @assert ec.id == id
  # ec.id = id
  ec
end

### Definition 2.3: canonicalization
iscanonical(g::EGraph, n::ENodeTerm) = n == canonicalize(g, n)
iscanonical(g::EGraph, n::ENodeLiteral) = true
iscanonical(g::EGraph, e::EClass) = find(g, e.id) == e.id

canonicalize(g::EGraph, n::ENodeLiteral) = n

function canonicalize(g::EGraph, n::ENodeTerm{T}) where {T}
  if arity(n) > 0
    new_args = map(x -> find(g, x), arguments(n))
    return ENodeTerm{T}(exprhead(n), operation(n), new_args)
  end
  return n
end

function canonicalize!(g::EGraph, n::ENodeTerm)
  args = arguments(n)
  for i in 1:arity(n)
    args[i] = find(g, args[i])
  end
  n.hash[] = UInt(0)
  return n
end

canonicalize!(g::EGraph, n::ENodeLiteral) = n


function canonicalize!(g::EGraph, e::EClass)
  e.id = find(g, e.id)
end

function lookup(g::EGraph, n::AbstractENode)
  cc = canonicalize(g, n)
  if !haskey(g.memo, cc)
    return nothing
  end
  return find(g, g.memo[cc])
end

"""
Inserts an e-node in an [`EGraph`](@ref)
"""
function add!(g::EGraph, n::AbstractENode)::EClass
  @debug("adding ", n)

  n = canonicalize(g, n)
  if haskey(g.memo, n)
    eclass = g[g.memo[n]]
    return eclass
  end
  @debug(n, " not found in memo")

  id = push!(g.uf) # create new singleton eclass

  if n isa ENodeTerm
    for c_id in arguments(n)
      addparent!(g.classes[c_id], n, id)
    end
  end

  g.memo[n] = id

  classdata = EClass(g, id, AbstractENode[n], Pair{AbstractENode,EClassId}[])
  g.classes[id] = classdata
  g.numclasses += 1

  for an in g.analyses
    if !islazy(an) && an !== :metadata_analysis
      setdata!(classdata, an, make(an, g, n))
      modify!(an, g, id)
    end
  end
  return classdata
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
addexpr!(g::EGraph, se::EClass; keepmeta = false) = (se, se[1])

function addexpr!(g::EGraph, se; keepmeta = false)::Tuple{EClass,AbstractENode}
  # println("========== $e ===========")
  e = preprocess(se)
  node = nothing

  if istree(se)
    exhead = exprhead(e)
    op = operation(e)
    args = arguments(e)

    n = length(args)

    class_ids = EClassId[first(addexpr!(g, child; keepmeta = keepmeta)).id for child in args]

    node = ENodeTerm{typeof(e)}(exhead, op, class_ids)
  else
    # constant enode
    node = ENodeLiteral(e)
  end

  ec = add!(g, node)
  if keepmeta
    # TODO check if eclass already has metadata?
    meta = TermInterface.metadata(e)
    setdata!(ec, :metadata_analysis, meta)
  end
  return (ec, node)
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

  @debug "merging" id_a id_b

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

  # for i ∈ 1:length(egraph.uf)
  #     find_root!(egraph.uf, i)
  # end
  # INVARIANTS ASSERTIONS
  # for (id, c) ∈  egraph.classes
  #     # ecdata.nodes = map(n -> canonicalize(egraph.uf, n), ecdata.nodes)
  #     println(id, "=>", c.id)
  #     @assert(id == c.id)
  #     # for an ∈ egraph.analyses
  #     #     if haskey(an, id)
  #     #         @assert an[id] == mapreduce(x -> make(an, x), (x, y) -> join(an, x, y), c.nodes)
  #     #     end
  #     # end

  #     for n ∈ c
  #         println(n)
  #         println("canon = ", canonicalize(egraph, n))
  #         hr = egraph.memo[canonicalize(egraph, n)]
  #         println(hr)
  #         @assert hr == find(egraph, id)
  #     end
  # end
  # display(egraph.classes); println()
  # @show egraph.dirty

end

function repair!(g::EGraph, id::EClassId)
  id = find(g, id)
  ecdata = g[id]
  ecdata.id = id
  @debug "repairing " id

  # for (p_enode, p_eclass) ∈ ecdata.parents
  #     clean_enode!(g, p_enode, find(g, p_eclass))
  # end

  new_parents = (length(ecdata.parents) > 30 ? OrderedDict : LittleDict){AbstractENode,EClassId}()

  for (p_enode, p_eclass) in ecdata.parents
    p_enode = canonicalize!(g, p_enode)
    # deduplicate parents
    if haskey(new_parents, p_enode)
      @debug "merging classes" p_eclass (new_parents[p_enode])
      merge!(g, p_eclass, new_parents[p_enode])
    end
    n_id = find(g, p_eclass)
    g.memo[p_enode] = n_id
    new_parents[p_enode] = n_id
  end

  ecdata.parents = collect(new_parents)
  @debug "updated parents " id g.parents[id]

  # ecdata.nodes = map(n -> canonicalize(g.uf, n), ecdata.nodes)

  # Analysis invariant maintenance
  for an in g.analyses
    hasdata(ecdata, an) && modify!(an, g, id)
    for (p_enode, p_id) in ecdata.parents
      # p_eclass = find(g, p_eclass)
      p_eclass = g[p_id]
      if !islazy(an) && !hasdata(p_eclass, an)
        setdata!(p_eclass, an, make(an, g, p_enode))
      end
      if hasdata(p_eclass, an)
        p_data = getdata(p_eclass, an)

        new_data = join(an, p_data, make(an, g, p_enode))
        if new_data != p_data
          setdata!(p_eclass, an, new_data)
          push!(g.dirty, p_id)
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
When extracting symbolic expressions from an e-graph, we need 
to instruct the e-graph how to rebuild expressions of a certain type. 
This function must be extended by the user to add new types of expressions that can be manipulated by e-graphs.
"""
function egraph_reconstruct_expression(T::Type{Expr}, op, args; metadata = nothing, exprhead = :call)
  similarterm(Expr(:call, :_), op, args; metadata = metadata, exprhead = exprhead)
end
