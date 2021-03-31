
# we keep a pair of EClass, Any in substitutions because
# when evaluating dynamic rules we also want to know
# what was the value of a matched literal

import Base.ImmutableDict

struct Sub 
    classes::ImmutableDict{PatVar, EClass}
    literals::ImmutableDict{PatVar, Any}
    termtypes::ImmutableDict{Any, Tuple{Type, NamedTuple}}
end

function Sub()
    Sub(ImmutableDict{PatVar, EClass}(), ImmutableDict{PatVar, Any}(),
    ImmutableDict{Any, Tuple{Type, NamedTuple}}())
end
Base.isempty(sub::Sub) = isempty(sub.classes)

haseclass(sub::Sub, p::PatVar) = haskey(sub.classes, p)
geteclass(sub::Sub, p::PatVar) = sub.classes[p]
function seteclass(sub::Sub, p::PatVar, c::EClass)::Sub
    Sub(ImmutableDict(sub.classes, p => c), sub.literals, sub.termtypes)
end

hasliteral(sub::Sub, p::PatVar) = haskey(sub.literals, p)
getliteral(sub::Sub, p::PatVar) = sub.literals[p]
function setliteral(sub::Sub, p::PatVar, x)::Sub
    Sub(sub.classes, ImmutableDict(sub.literals, p => x), sub.termtypes)
end

hastermtype(sub::Sub, p::Any) = haskey(sub.termtypes, p)
gettermtype(sub::Sub, p::Any) = sub.termtypes[p]
function settermtype(sub::Sub, p::Any, x::Type, meta::NamedTuple)::Sub
    Sub(sub.classes, sub.literals, ImmutableDict(sub.termtypes, p => (x, meta)))
end

function Base.show(io::IO, s::Sub)
    print(io, "Sub(")
    kvs = collect(s.classes)
    if !isempty(kvs)
        print(io, "Classes[")
        n = length(kvs)
        for i ∈ 1:n
            print(io, kvs[i][1], " => ", kvs[i][2].id)
            if i < n 
                print(io, ",")
            end
        end
        print(io, "] ")
    end
    kvs = collect(s.literals)
    if !isempty(kvs)
        print(io, "Literals[")
        n = length(kvs)
        for i ∈ 1:n
            print(io, kvs[i][1], " => ", kvs[i][2])
            if i < n 
                print(io, ",")
            end
        end
        print(io, "] ")
    end 
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

function instantiate(pat::PatVar, sub::Sub, rule::Rule)
    if haseclass(sub, pat)
        if hasliteral(sub, pat)
            return getliteral(sub, pat)
        else 
            return geteclass(sub, pat)
        end
    else
        error("unbound pattern variable $pat in rule $rule")
    end
end



function instantiate(pat::PatLiteral{T}, sub::Sub, rule::Rule) where T
    pat.val
end

function instantiate(pat::PatTypeAssertion, sub::Sub, rule::Rule)
    instantiate(pat.var, sub, rule)
end

# # TODO CUSTOMTYPES document how to for custom types
function instantiateterm(pat::PatTerm,  T::Type{Expr}, meta::Union{Nothing,NamedTuple}, sub::Sub, rule::Rule)
    meta = pat.metadata
    if meta !== nothing && meta.iscall
        Expr(:call, pat.head, map(x -> instantiate(x, sub, rule), pat.args)...)
    else
        Expr(pat.head, map(x -> instantiate(x, sub, rule), pat.args)...)
    end
end

function instantiate(pat::PatTerm, sub::Sub, rule::Rule)
    # TODO support custom types here!
    # similarterm ? ask Shashi
    # println(sub)
    # for (pp, tt) ∈ sub.termtypes
    #     println("$pp $(hash(pp))")
    #     println("$pat $(hash(pat))")
    #     println(pp == pat)
    # end
    if hastermtype(sub, pat.head)
        (T, meta) = gettermtype(sub, pat.head)
        instantiateterm(pat, T, meta, sub, rule)
    else 
        instantiateterm(pat, Expr, pat.metadata, sub, rule)
    end
end

