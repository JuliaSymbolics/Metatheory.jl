
# we keep a pair of EClass, Any in substitutions because
# when evaluating dynamic rules we also want to know
# what was the value of a matched literal

import Base.ImmutableDict

struct Sub 
    # classes::ImmutableDict{PatVar, EClass}
    classes::ImmutableDict{PatVar, Int64}
    literals::ImmutableDict{PatVar, Int}
    termtypes::ImmutableDict{Any, Tuple{Type, NamedTuple}}
    # cache::Dict{Pattern, Vector{Int64}}
end

function Sub() 
    # classes::ImmutableDict{PatVar, EClass}
    Sub(
        ImmutableDict{PatVar, Int64}(),
        ImmutableDict{PatVar, Int}(),
        ImmutableDict{Any, Tuple{Type, NamedTuple}}(),
        # Dict{Pattern, Vector{Int64}}()
    )
    # cache::Dict{Pattern, Vector{Int64}}
end

function Base.copy(s::Sub)
    Sub(copy(s.classes), copy(s.literals), copy(s.termtypes))# copy(s.cache))
end

# function Sub(nvars)
#     Sub(fill(-1, nvars), fill(-1, nvars), LittleDict{Any, Tuple{Type, NamedTuple}}())#, Dict{PatTerm, Vector{Int64}}())
# end
Base.isempty(sub::Sub) = isempty(sub.classes)

# function hascachedpat(sub::Sub, p::Pattern, id::Int64)
#     return haskey(sub.cache, p) && id ∈ sub.cache[p]
# end
# function addcachedpat(sub::Sub, p::Pattern, id::Int64)
#     if !haskey(sub.cache, p) 
#         sub.cache[p] = Int64[]
#     end
#     if !hascachedpat(sub, p, id)
#         push!(sub.cache[p], id)
#     end
# end

haseclassid(sub::Sub, p::PatVar) = haskey(sub.classes, p)
geteclassid(sub::Sub, p::PatVar) = sub.classes[p]
function seteclassid(sub::Sub, p::PatVar, c::Int64)::Sub
    Sub(ImmutableDict(sub.classes, p => c), sub.literals, sub.termtypes)
end
# function seteclassid!(sub::Sub, p::PatVar, id::Int64)
#     sub.classes[p.idx] = id
# end

hasliteral(sub::Sub, p::PatVar) = haskey(sub.literals, p)
getliteral(sub::Sub, p::PatVar) = sub.literals[p]
function setliteral(sub::Sub, p::PatVar, x)::Sub
    Sub(sub.classes, ImmutableDict(sub.literals, p => x), sub.termtypes)
end
# function setliteral!(sub::Sub, p::PatVar, position::Int)
#     sub.literals[p.idx] = position
# end


hastermtype(sub::Sub, p::Any) = haskey(sub.termtypes, p)
gettermtype(sub::Sub, p::Any) = sub.termtypes[p]
# function settermtype(sub::Sub, p::Any, x::Type, meta::NamedTuple)::Sub
#     Sub(sub.classes, sub.literals, ImmutableDict(sub.termtypes, p => (x, meta)))
# end

function settermtype(sub::Sub, p::Any, x::Type, meta::NamedTuple)
    Sub(sub.classes, sub.literals, ImmutableDict(sub.termtypes, p => (x, meta)))
end

function Base.show(io::IO, s::Sub)
    print(io, s.classes, ", ")
    print(io, s.literals, ", ")
    
    kvs = collect(s.termtypes)
    if !isempty(kvs)
        print(io, "TermTypes[")
        n = length(kvs)
        for i ∈ 1:n
            print(io, kvs[i][1], " => ", kvs[i][2])
            if i < n 
                print(io, ",")
            end
        end
        print(io, "] ")
    end

    print(io, ")")
end

const SubBuf = Vector{Sub}

## ====================== Instantiation =======================

function instantiate(g::EGraph, pat::PatVar, sub::Sub, rule::Rule)
    if haseclassid(sub, pat)
        ec = geteclass(g, geteclassid(sub, pat))
        if hasliteral(sub, pat)
            pos = getliteral(sub, pat)
            node = ec.nodes[pos]
            @assert arity(node) == 0
            return node.head
        end 
        return ec
    else
        error("unbound pattern variable $pat in rule $rule")
    end
end



function instantiate(g::EGraph, pat::PatLiteral{T}, sub::Sub, rule::Rule) where T
    pat.val
end

function instantiate(g::EGraph, pat::PatTypeAssertion, sub::Sub, rule::Rule)
    instantiate(g, pat.name, sub, rule)
end

# # TODO CUSTOMTYPES document how to for custom types
function instantiateterm(g::EGraph, pat::PatTerm,  T::Type{Expr}, meta::Union{Nothing,NamedTuple}, sub::Sub, rule::Rule)
    meta = pat.metadata
    if meta !== nothing && meta.iscall
        Expr(:call, pat.head, map(x -> instantiate(g, x, sub, rule), pat.args)...)
    else
        Expr(pat.head, map(x -> instantiate(g, x, sub, rule), pat.args)...)
    end
end

function instantiate(g::EGraph, pat::PatTerm, sub::Sub, rule::Rule)
    # println(sub)
    # for (pp, tt) ∈ sub.termtypes
    #     println("$pp $(hash(pp))")
    #     println("$pat $(hash(pat))")
    #     println(pp == pat)
    # end
    if hastermtype(sub, pat.head)
        (T, meta) = gettermtype(sub, pat.head)
        instantiateterm(g, pat, T, meta, sub, rule)
    else 
        instantiateterm(g, pat, Expr, pat.metadata, sub, rule)
    end
end
