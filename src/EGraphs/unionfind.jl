"""
    UnionFind()

Creates a new empty unionfind.

A unionfind data structure is an eventually-idempotent endomorphism on `1:n`.

What does this mean? It is a function `parents : 1:n -> 1:n` such that

```
parents^(n) = parents^(n+1)
```

This means that if you start at any `i ∈ 1:n`, repeatedly apply `parents` to `i`
will eventually reach a fixed-point. We call the fixed points of `parents` the "roots" of the unionfind. This is implemented in [`find`].

For the remaining discussion, let `parents*` the function which sends `i ∈ 1:n` to its fixed point with respect to `parents`.

The point of a unionfind is to store a *partition* of `1:n`. To test if two
elements `i, j ∈ 1:n` are in the same partition, we check if

```
parents*(i) = parents*(j)
```

That is, we check if `find(uf, i) == find(uf, j)`.
"""
struct UnionFind
  parents::Vector{Id}
end

UnionFind() = UnionFind(Id[])

"""
    Base.push(uf::UnionFind)::Id

This extends the domain of `uf` from `1:n` to `1:n+1` and returns `n+1`. The
element `n+1` is originally in its own equivalence class.
"""
function Base.push!(uf::UnionFind)::Id
  l = length(uf.parents) + 1
  push!(uf.parents, l)
  l
end

Base.length(uf::UnionFind) = length(uf.parents)

"""
    Base.union!(uf::UnionFind, i::Id, j::Id)

Precondition: `i` and `j` must be roots of `uf`.

Thus, we typically call this as `union!(uf, find(uf, i), find(uf, j))`. If this
precondition is not satisfied, then it is easy to violate the eventually-idempotent criterion of the unionfind.

Specifically,

```
union!(uf, 1, 2)
union!(uf, 2, 1)
```

will create a cycle that will make `find(uf, 1)` non-terminate.
"""
function Base.union!(uf::UnionFind, i::Id, j::Id)
  uf.parents[j] = i
  i
end


# Potential optimization:

# ```julia
# j = i
# while j != uf.parents[j]
#   j = uf.parents[j]
# end
# root = j
# while i != uf.parents[i]
#   uf.parents[i] = root
#   i = uf.parents[i]
# end
# root
# ```

# This optimization sets up a "short-circuit". That is, before, the parents array
# might be set up as

# ```
# 1 -> 5 -> 2 -> 3 -> 3
# ```

# After, we have

# ```
# 1 -> 3
# 5 -> 3
# 2 -> 3
# 3 -> 3
# ```

# Note: why don't we do this optimization? Question for Alessandro.

"""
    find(uf::UnionFind, i::Id)

This computes the fixed point of `uf.parents` when applied to `i`.

We know we are at a fixed point once `i == uf.parents[i]`. So, we continually
set `i = uf.parents[i]` until this becomes true.
"""
function find(uf::UnionFind, i::Id)
  while i != uf.parents[i]
    i = uf.parents[i]
  end
  i
end
