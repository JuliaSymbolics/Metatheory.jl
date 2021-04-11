using AutoHashEquals

@auto_hash_equals struct ENodePat
    head::Symbol
    args::Vector{Symbol}
end

@auto_hash_equals struct Bind 
    eclass::Symbol
    enodepat::ENodePat
end

@auto_hash_equals struct CheckClassEq
    eclass1::Symbol
    eclass2::Symbol
end

@auto_hash_equals struct Yield
    yields::Vector{Symbol}
end

function compile_pat(eclass, p::PatTerm, ctx)
    a = [gensym() for i in 1:length(p.args) ]
    return vcat(  Bind(eclass, ENodePat(p.head, a)) , [compile_pat(eclass, p2, ctx) for (eclass , p2) in zip(a, p.args)]...)
end

function compile_pat(eclass, p::PatVar, ctx)
    if haskey(ctx, p.name)
        return CheckClassEq(eclass, ctx[p.name])
    else
        ctx[p.name] = eclass
        return []
    end
end