struct IntDisjointSet
    parents::Vector{Int64}
end

IntDisjointSet() = IntDisjointSet(Vector{Int64}[])
Base.length(x::IntDisjointSet) = length(x.parents)

function Base.push!(x::IntDisjointSet)
    push!(x.parents, -1)
    length(x)
end
function find_root(x::IntDisjointSet, i::Int64)
    while x.parents[i] >= 0
        i = x.parents[i]
    end
    return i
end

function in_same_set(x::IntDisjointSet, a::Int64, b::Int64)
    find_root(x, a) == find_root(x, b)
end

function Base.union!(x::IntDisjointSet, i::Int64, j::Int64)
    pi = find_root(x, i)
    pj = find_root(x, j)
    if pi != pj
        isize = -x.parents[pi]
        jsize = -x.parents[pj]
        if isize > jsize # swap to make size of i less than j
            pi, pj = pj, pi
            isize, jsize = jsize, isize
        end
        x.parents[pj] -= isize # increase new size of pj
        x.parents[pi] = pj # set parent of pi to pj
    end
    return pj
end

function normalize!(x::IntDisjointSet)
    for i in length(x)
        pi = find_root(x, i)
        if pi != i
            x.parents[i] = pi
        end
    end
end

# If normalized we don't even need a loop here.
function _find_root_normal(x::IntDisjointSet, i::Int64)
    pi = x.parents[i]
    if pi < 0 # Is `i` a root?
        return i
    else
        return pi
    end
end

function _in_same_set_normal(x::IntDisjointSet, a::Int64, b::Int64)
    _find_root_normal(x, a) == _find_root_normal(x, b)
end