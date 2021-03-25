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
When creating a theory, type assertions in the left hand contain symbols.
We want to replace the type symbols with the real type values, to fully support
the subtyping mechanism during pattern matching.
"""
eval_types_in_assertions(x, mod::Module) = x
function eval_types_in_assertions(ex::Expr, mod::Module)
    if Meta.isexpr(ex, :(::))
        !(ex.args[1] isa Symbol) && error("Type assertion is not on pattern variable")
        ex.args[2] isa Type && (return ex)
        Expr(:(::), ex.args[1], getfield(mod, ex.args[2]))
    else 
        Expr(ex.head, map(x -> eval_types_in_assertions(x, mod), ex.args)...)
    end
end


"""
Construct a `Rule` from a quoted expression.
You can also use the [`@rule`] macro to
create a `Rule`.
"""
function Rule(e::Expr; mod::Module=@__MODULE__)
    e = rmlines(copy(e))
    e = interp_dollar(e, mod)
    op = gethead(e)

    # TODO catch this fancy error
    RuleType = rule_sym_map[op]
    l, r = e.args[Meta.isexpr(e, :call) ? (2:3) : (1:2)]
    # TODO move this to the macro
    l = df_walk(x -> eval_types_in_assertions(x, mod), l; skip_call=true)
    
    lhs = Pattern(l)
    rhs = r
    
    if RuleType <: SymbolicRule
        rhs = Pattern(rhs)
    end
    
    # TODO Fix this
    # patvars = collect(collect_symbols(remove_assertions(l)))
    return RuleType(lhs, rhs)
end



macro rule(e)
    Rule(e; mod=__module__)
end

# Theories can just be vectors of rules!

macro theory(e)
    e = macroexpand(__module__, e)
    e = rmlines(e)
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