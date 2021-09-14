# TODO document the additional parameters
"""
Rules defined as `left_hand => right_hand` are
called `dynamic` rules. Dynamic rules behave like anonymous functions.
Instead of a symbolic substitution, the right hand of
a dynamic `=>` rule is evaluated during rewriting:
matched values are bound to pattern variables as in a
regular function call. This allows for dynamic computation
of right hand sides.

Dynamic rule
```julia
@rule ~a::Number * ~b::Number => ~a*~b
```
"""
@auto_hash_equals struct DynamicRule <: AbstractRule
    expr # rule pattern stored for pretty printing
    left
    rhs_fun::Function
    matcher
    patvars::Vector{Symbol} # useful set of pattern variables
    ematch_program::Program
    mod::Module
end

function DynamicRule(l, r)
    ex = :($(to_expr(l)) => $(to_expr(r)))
    DynamicRule(ex, l, r, m)
end

function DynamicRule(ex::Expr, l, r::Expr, mod=@__MODULE__)
    pvars = patvars(l)
    setdebrujin!(l, pvars)

    params = Expr(:tuple, :_lhs_expr, :_subst, :_egraph, pvars...)
    ex = :($params -> $r)
    f = closure_generator(mod, ex)

    DynamicRule(ex, l, f, pvars, compile_pat(l), mod)
end

function DynamicRule(ex::Expr, l, r::Function, mod=@__MODULE__)
    pvars = patvars(l)
    setdebrujin!(l, pvars)

    DynamicRule(ex, l, r, matcher(l), pvars, compile_pat(l), mod)
end


Base.show(io::IO, r::DynamicRule) = print(io, r.expr)
