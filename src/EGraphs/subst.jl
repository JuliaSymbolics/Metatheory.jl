struct Sub
    # sourcenode::Union{Nothing, AbstractENode}
    ids::Vector{EClassId}
    nodes::Vector{Union{Nothing, ENodeLiteral}}
end

haseclassid(sub::Sub, p::PatVar) = sub.ids[p.idx] >= 0
geteclassid(sub::Sub, p::PatVar) = sub.ids[p.idx]

hasliteral(sub::Sub, p::PatVar) = sub.nodes[p.idx] !== nothing
getliteral(sub::Sub, p::PatVar) = sub.nodes[p.idx] 

## ====================== Instantiation =======================

function instantiate(g::EGraph, pat::PatVar, sub::Sub, rule::AbstractRule)
    if haseclassid(sub, pat)
        ec = geteclass(g, geteclassid(sub, pat))
        if hasliteral(sub, pat) 
            node = getliteral(sub, pat)
            return node.value
        end 
        return ec
    else
        error("unbound pattern variable $pat in rule $rule")
    end
end

instantiate(g::EGraph, pat::Any, sub::Sub, rule::AbstractRule) = pat
instantiate(g::EGraph, pat::Pattern, sub::Sub, rule::AbstractRule) = 
    throw(UnsupportedPatternException(pat))

function instantiate(g::EGraph, pat::PatTerm, sub::Sub, rule::AbstractRule)
    eh = exprhead(pat)
    op = operation(pat)
    ar = arity(pat)

    T = gettermtype(g, op, ar)
    children = map(x -> instantiate(g, x, sub, rule), arguments(pat))
    similarterm(T, op, children; exprhead=eh)
end

