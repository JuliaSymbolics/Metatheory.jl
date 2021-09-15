
"""
```julia
@rule ~a * ~b == ~b * ~a
```
"""
@auto_hash_equals struct EqualityRule <: BidirRule 
    expr # rule pattern stored for pretty printing
    left
    right
    patvars::Vector{Symbol}
    ematch_program_l::Program
    ematch_program_r::Program
end

function EqualityRule(ex, l, r)
    pvars = patvars(l) ∪ patvars(r)
    extravars = setdiff(pvars, patvars(l) ∩ patvars(r))
    if !isempty(extravars)
        error("unbound pattern variables $extravars when creating bidirectional rule")
    end
    setdebrujin!(l, pvars)
    setdebrujin!(r, pvars)
    progl = compile_pat(l)
    progr = compile_pat(r)
    EqualityRule(ex, l, r, pvars, progl, progr)
end

function EqualityRule(l, r)
    EqualityRule(gensym(:rule), l, r)
end

Base.show(io::IO,  r::EqualityRule) = print(io, r.expr)

