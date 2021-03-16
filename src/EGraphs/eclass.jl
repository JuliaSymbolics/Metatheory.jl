

const Parent = Tuple{ENode,Int64} # parent enodes and eclasses
mutable struct EClassData
    id::Int64
    nodes::Set{ENode}
    parents::Dict{ENode, Int64}
end

# Interface for indexing EClassData
Base.getindex(a::EClassData, i) = a.nodes[i]
Base.setindex!(a::EClassData, v, i) = setindex!(a.nodes, v, i)
Base.firstindex(a::EClassData) = firstindex(a.nodes)
Base.lastindex(a::EClassData) = lastindex(a.nodes)

# Interface for iterating EClassData
Base.iterate(a::EClassData) = iterate(a.nodes)
Base.iterate(a::EClassData, state) = iterate(a.nodes, state)

# Showing
Base.show(io::IO, a::EClassData) = Base.show(io, a.nodes)

EClassData(id::Int64) = EClassData(id, Set{ENode}(), Dict{ENode, Int64}())

function addparent!(a::EClassData, n::ENode, id::Int64)
    a.parents[n] = id
end

function Base.union(to::EClassData, from::EClassData)
    EClassData(to.id, from.nodes ∪ to.nodes, from.parents ∪ to.parents)
end

function Base.union!(to::EClassData, from::EClassData)
    union!(to.nodes, from.nodes)
    merge!(to.parents, from.parents)
    return to
end
