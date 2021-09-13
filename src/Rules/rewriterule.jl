
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
    patvars::Vector{Symbol}
    ematch_program::Program
end

function RewriteRule(l, r)
    ex = :($(to_expr(l)) --> $(to_expr(r)))
    RewriteRule(ex, l, r)
end

function RewriteRule(ex::Expr, l, r)
    pvars = patvars(l) ∪ patvars(r)
    # sort!(pvars)
    setdebrujin!(l, pvars)
    setdebrujin!(r, pvars)
    RewriteRule(ex, l, r, pvars, compile_pat(l))
end

Base.show(io::IO,  r::RewriteRule) = print(io, r.expr)