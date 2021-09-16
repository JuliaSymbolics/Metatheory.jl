
"""
Rules defined as `left_hand --> right_hand` are
called *symbolic rewrite* rules. Application of a *rewrite* Rule
is a replacement of the `left_hand` pattern with
the `right_hand` substitution, with the correct instantiation
of pattern variables. Function call symbols are not treated as pattern
variables, all other identifiers are treated as pattern variables.
Literals such as `5, :e, "hello"` are not treated as pattern
variables.


```julia
@rule ~a * ~b --> ~b * ~a
```
"""
@auto_hash_equals struct RewriteRule <: SymbolicRule 
    expr # rule pattern stored for pretty printing
    left
    right
    matcher
    patvars::Vector{Symbol}
    ematch_program::Program
end

function RewriteRule(l, r)
    # ex = :($(to_expr(l)) --> $(to_expr(r)))
    RewriteRule(gensym(:rule), l, r)
end

function RewriteRule(ex, l, r)
    pvars = patvars(l) ∪ patvars(r)
    # sort!(pvars)
    setdebrujin!(l, pvars)
    setdebrujin!(r, pvars)
    RewriteRule(ex, l, r, matcher(l), pvars, compile_pat(l))
end

Base.show(io::IO,  r::RewriteRule) = print(io, r.expr)


function (r::RewriteRule)(term)
    mem = Vector(undef, length(r.patvars))
    # n == 1 means that exactly one term of the input (term,) was matched
    success(n) = n == 1 ? instantiate(term, r.right, mem) : nothing
        
    # try
        return r.matcher(success, (term,), mem)
    
    # catch err
        # throw(RuleRewriteError(r, term))
    # end
end