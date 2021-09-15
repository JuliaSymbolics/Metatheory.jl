
"""
This type of *anti*-rules is used for checking contradictions in the EGraph
backend. If two terms, corresponding to the left and right hand side of an
*anti-rule* are found in an [`EGraph`], saturation is halted immediately. 
"""
@auto_hash_equals struct UnequalRule <: BidirRule 
    expr # rule pattern stored for pretty printing
    left
    right
    patvars::Vector{Symbol}
    ematch_program_l::Program
    ematch_program_r::Program
end


function UnequalRule(l, r)
    UnequalRule(gensym(:rule), l, r)
end

function UnequalRule(ex, l, r)
    pvars = patvars(l) ∪ patvars(r)
    extravars = setdiff(pvars, patvars(l) ∩ patvars(r))
    if !isempty(extravars)
        error("unbound pattern variables $extravars when creating bidirectional rule")
    end
# sort!(pvars)
    setdebrujin!(l, pvars)
    setdebrujin!(r, pvars)
    progl = compile_pat(l)
    progr = compile_pat(r)
    UnequalRule(ex, l, r, pvars, progl, progr)
end

Base.show(io::IO, r::UnequalRule) = print(io, r.expr)
