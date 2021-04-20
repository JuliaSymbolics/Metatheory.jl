# This file contains specification and implementation 
# Of the homoiconic DSL for defining rules and theories 
using MatchCore

function rule_sym_map(ex)
    @smatch ex begin 
        :($a => $b) => RewriteRule
        :($a |> $b) => DynamicRule
        :($a == $b) => EqualityRule
        :($a != $b) => UnequalRule
        :($a ≠ $b) => UnequalRule
        _ => error("Cannot parse rule from $ex")
    end
end


interp_dollar(x, mod::Module) = x
function interp_dollar(ex::Expr, mod::Module)
    if Meta.isexpr(ex, :$)
        mod.eval(ex.args[1])
    else 
        Expr(ex.head, map(x -> interp_dollar(x, mod), ex.args)...)
    end
end


"""
Construct a `Rule` from a quoted expression.
You can also use the [`@rule`] macro to
create a `Rule`.
"""
function Rule(e::Expr; mod::Module=@__MODULE__)
    op = gethead(e)
    RuleType = rule_sym_map(e)
    l, r = e.args[Meta.isexpr(e, :call) ? (2:3) : (1:2)]
    
    lhs = Pattern(l, mod)
    rhs = r
    
    if RuleType <: SymbolicRule
        rhs = Pattern(rhs, mod)
    end

    
    return RuleType(lhs, rhs)
end

# fallback when defining theories and there's already a rule 
function Rule(r::Rule; mod::Module=@__MODULE__)
    r
end

macro rule(e)
    e = macroexpand(__module__, e)
    e = rmlines(copy(e))
    # e = interp_dollar(e, __module__)
    Rule(e; mod=__module__)
end

# Theories can just be vectors of rules!

macro theory(e)
    e = macroexpand(__module__, e)
    e = rmlines(e)
    # e = interp_dollar(e, __module__)
    if Meta.isexpr(e, :block)
        Vector{Rule}(e.args .|> x -> Rule(x; mod=__module__))
    else
        error("theory is not in form begin a => b; ... end")
    end
end

"""
A Theory is either a vector of [`Rule`](@ref) or
a compiled, callable function.
"""
const Theory = Union{Vector{<:Rule}, Function}


# lhs = Pattern(:(x * x))
# rhs = Pattern(:(x ^ 2))
# UnequalRule(lhs, rhs)
# Rule(:(x*x => x^2))
# Rule(:(x*x::Number |> x*x)) |> dump
# Rule(:(x*x == x^2))