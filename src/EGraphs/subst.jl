struct Sub
    sourcenode::Union{Nothing, AbstractENode}
    ids::Vector{EClassId}
    nodes::Vector{Union{Nothing, AbstractENode}}
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
            @assert arity(node) == 0
            return operation(node)
        end 
        return ec
    else
        error("unbound pattern variable $pat in rule $rule")
    end
end

function instantiate(g::EGraph, pat::PatLiteral{T}, sub::Sub, rule::AbstractRule) where T
    pat.val
end

function instantiate(g::EGraph, pat::PatTypeAssertion, sub::Sub, rule::AbstractRule)
    instantiate(g, pat.name, sub, rule)
end


function instantiate(g::EGraph, pat::PatTerm, sub::Sub, rule::AbstractRule)
    eh = exprhead(pat)
    op = operation(pat)
    ar = arity(pat)

    T = gettermtype(g, op, ar)
    children = map(x -> instantiate(g, x, sub, rule), arguments(pat))
    similarterm(T, op, children; exprhead=eh)
end

