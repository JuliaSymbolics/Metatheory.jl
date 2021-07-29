# Vector of (eclassid, position_of_literal_in_eclass_nodes)
struct Sub
    sourcenode::Union{Nothing, ENode}
    ids::Vector{EClassId}
    nodes::Vector{Union{Nothing,ENode}}
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
            return node.head
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
    f = pat.head
    ar = arity(pat)
    if pat.head == :call 
        @assert pat.args[1] isa PatLiteral
        f = pat.args[1].val
        ar = ar-1
    end

    T = gettermtype(g, f, ar)
    children = map(x -> instantiate(g, x, sub, rule), pat.args)
    similarterm(T, pat.head, children)
end
