module NewSyntax
using Metatheory.Patterns
using Metatheory.Rules
using TermInterface
    # Pattern Syntax

using Metatheory: alwaystrue, cleanast, binarize 


export to_expr
export Pattern    
export @rule
export @theory
export @methodrule
export @methodtheory

# FIXME this thing eats up macro calls!
"""
Remove LineNumberNode from quoted blocks of code
"""
rmlines(e::Expr) = Expr(e.head, map(rmlines, filter(x -> !(x isa LineNumberNode), e.args))...)
rmlines(a) = a


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
    getproperty(mod, f)
end

function makepredicate(f::Expr, mod::Module)::Union{Function,Type}
    mod.eval(f)
end


PatternExpr(x::Symbol, mod=@__MODULE__) = PatVar(x)
# treat as a literal
PatternExpr(x, mod=@__MODULE__) = x
PatternExpr(x::QuoteNode, mod=@__MODULE__) = x.value isa Symbol ? x.value : x

"""
You can use the `Pattern` constructor to recursively convert an `Expr` (or
any type satisfying [`Metatheory.TermInterface`](@ref)) to an
[`AbstractPat`](@ref).
"""

function PatternExpr(ex::Expr, mod=@__MODULE__)
    ex = cleanast(ex)

    head = exprhead(ex)
    op = operation(ex)
    args = arguments(ex)
    istree(op) && throw(Meta.ParseError("Unsupported pattern syntax $ex"))
    op = op isa Symbol ? Meta.quot(op) : op

    
    if head === :call
        patargs = map(i -> PatternExpr(i, mod), args) # recurse
        return quote PatTerm(:call, $op, $patargs, $mod) end
    elseif head === :(...)
        return makesegment(args[1], mod)
    elseif head === :(::)
        return makevar(ex, mod)
    elseif head === :ref 
        # getindex 
        return quote PatTerm($head, $getindex, $(map(i -> PatternExpr(i, mod), args)), $mod) end
    elseif head === :$
        return esc(args[1])
    elseif head isa Symbol
        h = Meta.quot(head)
        return quote PatTerm($h, $h, $(map(i -> PatternExpr(i, mod), args)), $mod) end
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
macro rule(e)
    e = macroexpand(__module__, e)
    e = rmlines(copy(e))
    op = operation(e)
    RuleType = rule_sym_map(e)
    
    l, r = arguments(e)
    lhs = PatternExpr(l, __module__)
    rhs = RuleType <: SymbolicRule ? PatternExpr(r, __module__) : r

    if RuleType == DynamicRule
        rhs = rewrite_rhs(r)
        pvars = patvars(lhs)
        params = Expr(:tuple, :_lhs_expr, :_subst, :_egraph, pvars...)
        rhs =  :($(esc(params)) -> $(esc(rhs)))
    end

    return quote 
        $(__source__)
        ($RuleType)($(QuoteNode(e)), $lhs, $rhs)
    end
end


macro methodrule(e)
    esc(:(Metatheory.@rule($e,true)))
end

# Theories can just be vectors of rules!

macro theory(e)
    e = macroexpand(__module__, e)
    e = rmlines(e)
    # e = interp_dollar(e, __module__)

    if exprhead(e) == :block
        ee = Expr(:vect, map(x -> :(@rule($x)), arguments(e))...)
        esc(ee)
    else
        error("theory is not in form begin a => b; ... end")
    end
end

# TODO document this puts the function as pattern head instead of symbols
macro methodtheory(e)
    :(@theory($(esc(e)), true))
end


# TODO ADD ORIGINAL CODE OF PREDICATE TO PATVAR

function to_expr(x::PatVar)
    if x.predicate == alwaystrue
        x.name
    else
        Expr(:(::), x.name, x.predicate)
    end
end

to_expr(x::Any) = x

function to_expr(x::PatSegment)
    if x.predicate == alwaystrue
        Expr(:..., x.name)
    else
        Expr(:..., Expr(:(::), x.name, x.predicate))
    end
end

function to_expr(x::PatTerm) 
    pl = operation(x)
    similarterm(Expr, pl, map(to_expr, arguments(x)); exprhead=exprhead(x))
end

function Base.show(io::IO, x::AbstractPat) 
    expr = to_expr(x)
    print(io, expr)
end


end