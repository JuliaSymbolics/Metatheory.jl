# Vector of (eclassid, position_of_literal_in_eclass_nodes)
const Sub = Vector{Tuple{Int64, Int64}}

haseclassid(sub::Sub, p::PatVar) = first(sub[p.idx]) >= 0
geteclassid(sub::Sub, p::PatVar) = first(sub[p.idx])

hasliteral(sub::Sub, p::PatVar) = last(sub[p.idx]) > 0
getliteral(sub::Sub, p::PatVar) = last(sub[p.idx])

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
function instantiateterm(g::EGraph, pat::PatTerm,  T::Type{Expr}, sub::Sub, rule::Rule)
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
    # if hastermtype(sub, pat.head)
        # (T, meta) = gettermtype(sub, pat.head)
        # instantiateterm(g, pat, T, meta, sub, rule)
    # else 
    # dump(pat)
    instantiateterm(g, pat, Expr, sub, rule)
    # end
end
