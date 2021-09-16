module NewSyntax
using Metatheory.Rules 
using Metatheory.Patterns
using Metatheory.Util
using TermInterface
    # Pattern Syntax

using Metatheory:alwaystrue

include("to_expr.jl")
export to_expr

export Pattern    
export @rule
export @theory
export @methodrule
export @methodtheory


# Resolve `GlobalRef` instances to literals.
resolve(gr::GlobalRef) = getproperty(gr.mod, gr.name)
resolve(gr) = gr


function makesegment(s::Expr, mod::Module)
    if !(exprhead(s) == :(::))
        error("Syntax for specifying a segment is x::\$predicate..., where predicate is a boolean function or a type")
    end

    name = arguments(s)[1]
    p = makepredicate(arguments(s)[2], mod)
    PatSegment(name, -1, p)
end
makesegment(s::Symbol, mod) = PatSegment(s)

function makevar(s::Expr, mod::Module)
    if !(exprhead(s) == :(::))
        error("Syntax for specifying a slot is x::\$predicate, where predicate is a boolean function or a type")
    end

    name = arguments(s)[1]
    p = makepredicate(arguments(s)[2], mod)
    PatVar(name, -1, p)
end
makevar(name::Symbol, mod) = PatVar(name)


function makepredicate(f::Symbol, mod::Module)::Union{Function,Type}
    resolve(GlobalRef(mod, f))
end

function makepredicate(f::Expr, mod::Module)::Union{Function,Type}
    mod.eval(f)
end


Pattern(x::Symbol, mod=@__MODULE__, resolve_fun=false) = PatVar(x)
# treat as a literal
Pattern(x, mod=@__MODULE__, resolve_fun=false) = x
Pattern(x::QuoteNode, mod=@__MODULE__, resolve_fun=false) = x.value isa Symbol ? x.value : x

"""
You can use the `Pattern` constructor to recursively convert an `Expr` (or
any type satisfying [`Metatheory.TermInterface`](@ref)) to an
[`AbstractPat`](@ref).
"""

function Pattern(ex::Expr, mod=@__MODULE__, resolve_fun=false)
    ex = cleanast(ex)

    head = exprhead(ex)
    op = operation(ex)
    args = arguments(ex)

    istree(op) && throw(Meta.ParseError("Unsupported pattern syntax $ex"))

    
    if head === :call
        if resolve_fun && op isa Symbol 
            op = resolve(GlobalRef(mod, op))
        end         
        patargs = map(i -> Pattern(i, mod, resolve_fun), args) # recurse
        PatTerm(head, op, patargs)
    elseif head === :(...)
        makesegment(args[1], mod)
    elseif head === :(::)
        makevar(ex, mod)
    elseif head === :ref 
        # getindex 
        PatTerm(head, resolve_fun ? getindex : :getindex,
            map(i -> Pattern(i, mod, resolve_fun), args))
    elseif head === :$
        return mod.eval(args[1])
    else
        return PatTerm(head, head, map(i -> Pattern(i, mod, resolve_fun), args))
    end
end

# Rule DSL

function rule_sym_map(ex::Expr)
    h = operation(ex)
    if h == :(=>) RewriteRule
    elseif h == :(|>)  DynamicRule
    elseif h == :(==) EqualityRule
    elseif h == :(!=) || h == :(≠) UnequalRule
    else error("Cannot parse rule with operator '$h'")
    end
end
rule_sym_map(ex) = error("Cannot parse rule from $ex")

"""
    rewrite_rhs(expr::Expr)

Rewrite the `expr` by dealing with `:where` if necessary.
The `:where` is rewritten from, for example, `x where f(x)` to `f(x) ? x : nothing`.
"""
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
        pvars = patvars(lhs)
        params = Expr(:tuple, :_lhs_expr, :_subst, :_egraph, pvars...)
        rhs_fun =  :($(esc(params)) -> $(esc(rhs)))
        
        if lhs isa Union{Symbol,Expr}
            lhs = Meta.quot(lhs)
        end
        
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
    esc(:(Metatheory.@rule($e,true)))
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
    :(@theory($(esc(e)), true))
end



end