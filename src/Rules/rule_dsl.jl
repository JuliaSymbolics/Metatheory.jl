# This file contains specification and implementation 
# Of the homoiconic DSL for defining rules and theories 

const rule_sym_map = Dict{Symbol, Type}(
    :(=>) => RewriteRule,
    :(|>) => DynamicRule,
    :(==) => EqualityRule,
    :(!=) => UnequalRule,
    :(≠) => UnequalRule
)

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
function Rule(e::Expr; mod::Module=@__MODULE__, prune=false)
    op = gethead(e)

    RuleType = Union{}
    try 
        RuleType = rule_sym_map[op]
    catch e
        if e isa KeyError
            error("Unknown Rule operator $op")
        else
            rethrow(e)
        end
    end
    l, r = e.args[Meta.isexpr(e, :call) ? (2:3) : (1:2)]
    
    lhs = Pattern(l, mod)
    rhs = r
    
    if RuleType <: SymbolicRule
        rhs = Pattern(rhs, mod)
    end
    
    if canprune(RuleType)
        return RuleType(lhs, rhs, prune)
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
    e = interp_dollar(e, __module__)
    Rule(e; mod=__module__)
end

"""
Generates a rule with the `prune` attribute set to true,
which deletes all other nodes in an e-class when applied (pruning). 
Can only be used with the equality saturation *e-graphs* backend.
"""
macro pruningrule(e)
    e = macroexpand(__module__, e)
    e = rmlines(copy(e))
    e = interp_dollar(e, __module__)
    r = Rule(e; mod=__module__, prune=true)
end

# Theories can just be vectors of rules!

macro theory(e)
    e = macroexpand(__module__, e)
    e = rmlines(e)
    e = interp_dollar(e, __module__)
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