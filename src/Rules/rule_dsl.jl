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
    elseif h == :(!=) || h == :(≠) UnequalRule
    else error("Cannot parse rule with operator '$h'")
    end
end

rule_sym_map(ex) = error("Cannot parse rule from $ex")

function rewrite_rhs(ex::Expr)
    if exprhead(ex) == :where 
        args = arguments(ex)
        rhs = args[1]
        predicate = args[2]
        ex = :($predicate ? $rhs : nothing)
    end
    return ex
end
rewrite_rhs(x) = x

"""
Construct an `AbstractRule` from an expression.
"""
macro rule(e, resolve_fun=false)
    e = macroexpand(__module__, e)
    e = rmlines(copy(e))
    op = operation(e)
    RuleType = rule_sym_map(e)
    
    l, r = arguments(e)
    lhs = Pattern(l, __module__, resolve_fun)
    rhs = r

    if RuleType == DynamicRule
        rhs = rewrite_rhs(r)
        rhs = makeconsequent(rhs)
        pvars = patvars(lhs)
        params = Expr(:tuple, :_lhs_expr, :_subst, :_egraph, pvars...)
        # FIXME bug
        rhs_fun =  :($(esc(params)) -> $(esc(rhs)))

        return quote 
            DynamicRule($(Meta.quot(e)), $lhs, $rhs_fun, $(__module__))
        end
    end

    if RuleType <: SymbolicRule
        rhs = Pattern(rhs, __module__, resolve_fun)
    end
    
    return RuleType(e, lhs, rhs)
end

macro methodrule(e)
    quote 
        @rule $e true
    end
end

# Theories can just be vectors of rules!

macro theory(e, resolve_fun=false)
    e = macroexpand(__module__, e)
    e = rmlines(e)
    # e = interp_dollar(e, __module__)

    if exprhead(e) == :block
        ee = Expr(:vect, map(x -> :(@rule($x, $resolve_fun)), arguments(e))...)
        esc(ee)
    else
        error("theory is not in form begin a => b; ... end")
    end
end

# TODO document this puts the function as pattern head instead of symbols
macro methodtheory(e)
    quote 
        @theory $e true
    end
end
