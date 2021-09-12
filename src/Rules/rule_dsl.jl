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
    h = operation(ex)
    if h == :(-->) || h == :(→) RewriteRule
    elseif h == :(=>)  DynamicRule
    elseif h == :(==) EqualityRule
    elseif h == :(!=) UnequalRule
    elseif h == :(≠) UnequalRule
    else error("Cannot parse rule with operator '$h'")
    end
end

rule_sym_map(ex) = error("Cannot parse rule from $ex")



"""
Construct an `AbstractRule` from a quoted expression.
You can also use the [`@rule`] macro to
create a `Rule`.
"""
function Rule(e::Expr, mod::Module=@__MODULE__, resolve_fun=false)
    op = operation(e)
    RuleType = rule_sym_map(e)
    l, r = e.args[Meta.isexpr(e, :call) ? (2:3) : (1:2)]
    
    lhs = Pattern(l, mod, resolve_fun)
    rhs = r
    
    if RuleType <: SymbolicRule
        println(RuleType)
        rhs = Pattern(rhs, mod, resolve_fun)
    end

    if RuleType == DynamicRule
        # FIXME make consequent like in SU
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
