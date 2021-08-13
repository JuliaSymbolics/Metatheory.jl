# This file contains specification and implementation 
# Of the homoiconic DSL for defining rules and theories 

"""
Retrieve a theory from a module at compile time.
TODO cleanup
"""
function gettheory(var, mod)
	t = nothing
    if Meta.isexpr(var, :block) # @matcher begine rules... end
		t = rmlines(macroexpand(mod, var)).args .|> Rule
	else
		t = mod.eval(var)
	end

	return t
end

function rule_sym_map(ex::Expr)
    if Meta.isexpr(ex, :call)
        h = ex.args[1]
        if h == :(=>) RewriteRule
        elseif h == :(|>) DynamicRule
        elseif h == :(==) EqualityRule
        elseif h == :(!=) UnequalRule
        elseif h == :(≠) UnequalRule
        end
    end
end

rule_sym_map(ex) = error("Cannot parse rule from $ex")


interp_dollar(x, mod::Module) = x
function interp_dollar(ex::Expr, mod::Module)
    if Meta.isexpr(ex, :$)
        mod.eval(ex.args[1])
    else 
        Expr(ex.head, map(x -> interp_dollar(x, mod), ex.args)...)
    end
end


"""
Construct an `AbstractRule` from a quoted expression.
You can also use the [`@rule`] macro to
create a `Rule`.
"""
function Rule(e::Expr, mod::Module=@__MODULE__, resolve_fun=false)
    op = gethead(e)
    RuleType = rule_sym_map(e)
    l, r = e.args[Meta.isexpr(e, :call) ? (2:3) : (1:2)]
    
    l = interp_dollar(l, mod)

    if RuleType !== DynamicRule
        r = interp_dollar(r, mod)
    end

    lhs = Pattern(l, mod, resolve_fun)
    rhs = r
    
    if RuleType <: SymbolicRule
        rhs = Pattern(rhs, mod, resolve_fun)
    end

    if RuleType == DynamicRule
        return DynamicRule(lhs, rhs, mod)
    end
    
    return RuleType(lhs, rhs)
end

# fallback when defining theories and there's already a rule 
function Rule(r::AbstractRule, mod::Module=@__MODULE__, resolve_fun=false)
    r
end

macro rule(e)
    e = macroexpand(__module__, e)
    e = rmlines(copy(e))
    Rule(e, __module__, false)
end

macro methodrule(e)
    e = macroexpand(__module__, e)
    e = rmlines(copy(e))
    Rule(e, __module__, true)
end

# Theories can just be vectors of rules!

macro theory(e)
    e = macroexpand(__module__, e)
    e = rmlines(e)
    # e = interp_dollar(e, __module__)
    if Meta.isexpr(e, :block)
        Vector{AbstractRule}(e.args .|> x -> Rule(x, __module__, false))
    else
        error("theory is not in form begin a => b; ... end")
    end
end

# TODO document this puts the function as pattern head instead of symbols
macro methodtheory(e)
    e = macroexpand(__module__, e)
    e = rmlines(e)
    # e = interp_dollar(e, __module__)
    if Meta.isexpr(e, :block)
        Vector{AbstractRule}(e.args .|> x -> Rule(x, __module__, true))
    else
        error("theory is not in form begin a => b; ... end")
    end
end

"""
A Theory is either a vector of [`Rule`](@ref) or
a compiled, callable function.
"""
const Theory = Union{Vector{<:AbstractRule}, Function}

