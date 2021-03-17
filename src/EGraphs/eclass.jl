using Parameters

const AnalysisData = ImmutableDict{Type{<:AbstractAnalysis}, Any}

mutable struct EClassData
    id::Int64
    nodes::OrderedSet{ENode}
    parents::OrderedDict{ENode, Int64}
    data::Union{Nothing, AnalysisData}
end
EClassData(id) = EClassData(id, OrderedSet{ENode}(), OrderedDict{ENode, Int64}(), nothing)
EClassData(id, nodes, parents) = EClassData(id, nodes, parents, nothing)

# Interface for indexing EClassData
Base.getindex(a::EClassData, i) = a.nodes[i]
Base.setindex!(a::EClassData, v, i) = setindex!(a.nodes, v, i)
Base.firstindex(a::EClassData) = firstindex(a.nodes)
Base.lastindex(a::EClassData) = lastindex(a.nodes)

# Interface for iterating EClassData
Base.iterate(a::EClassData) = iterate(a.nodes)
Base.iterate(a::EClassData, state) = iterate(a.nodes, state)

# Showing
# Base.show(io::IO, a::EClassData) = Base.show(io, a.nodes)
#
# function addparent!(a::EClassData, n::ENode, p::EClassData)
#     a.parents[n] = p
# end

function addparent!(a::EClassData, n::ENode, id::Int64)
    a.parents[n] = id
end

function Base.union(to::EClassData, from::EClassData)
    EClassData(to.id, from.nodes ∪ to.nodes, from.parents ∪ to.parents, from.data ∪ to.data)
end

function Base.union!(to::EClassData, from::EClassData)
    union!(to.nodes, from.nodes)
    merge!(to.parents, from.parents)
    if to.data != nothing && from.data != nothing
        # merge!(to.data, from.data)
        # to.data = join_analysis_data(to.data, from.data)
        to.data = join_analysis_data(to.data, from.data)
    elseif to.data == nothing
        to.data = from.data
    end
    return to
end

function join_analysis_data(d::AnalysisData, dsrc::AnalysisData)
    for (an, val_b) in dsrc
        if haskey(d, an)
            val_a = d[an]
            nv = join(an, val_a, val_b)
            # d[an] = nv
            # WARNING immutable version
            d = Base.ImmutableDict(d,an=>nv)
        end
    end
    return d
end

# mutable version
function join_analysis_data(d::AnalysisData, dsrc::AnalysisData)
    for (an, val_b) in dsrc
        if haskey(d, an)
            val_a = d[an]
            nv = join(an, val_a, val_b)
        end
    end
    return d
end

# Thanks to Shashi Gowda
function hasdata(a::EClassData, x::Type{<:AbstractAnalysis})
    a.data == nothing && (return false)
    return haskey(a.data, x)
end

function getdata(a::EClassData, x::Type{<:AbstractAnalysis})
    !hasdata(a, x) && error("EClass does not contain analysis data for $x")
    return a.data[x]
end

function getdata(a::EClassData, x::Type{<:AbstractAnalysis}, default)
    hasdata(a, x) ? a.data[x] : default
end

function setdata!(a::EClassData, x::Type{<:AbstractAnalysis}, value)
    # lazy allocation
    a.data == nothing && (a.data = AnalysisData())
    # a.data[x] = value
    a.data = AnalysisData(a.data, x, value)
end
