

const Parent = Tuple{ENode,Int64} # parent enodes and eclasses
mutable struct EClassData
    id::Int64
    nodes::Vector{ENode}
    parents::Vector{Parent}
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

EClassData(id::Int64) = EClassData(id, [], Parent[])

function addparent!(a::EClassData, parent::Parent)
    if parent ∉ a.parents
        push!(a.parents, parent)
    end
end

function Base.union(from::EClassData, to::EClassData)
    EClassData(to.id, from.nodes ∪ to.nodes, from.parents ∪ to.parents)
end

function Base.union!(to::EClassData, from::EClassData)
    union!(to.nodes, from.nodes)
    union!(to.parents, from.parents)
    return to
end
