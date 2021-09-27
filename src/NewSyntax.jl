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


function makesegment(s::Expr, pvars)
    if !(exprhead(s) == :(::))
        error("Syntax for specifying a segment is x::\$predicate..., where predicate is a boolean function or a type")
    end

    name = arguments(s)[1]
    name ∉ pvars && push!(pvars, name)
    return :(PatSegment($(QuoteNode(name)), -1, $(arguments(s)[2])))
end
function makesegment(name::Symbol, pvars) 
    name ∉ pvars && push!(pvars, name)
    PatSegment(name)
end
function makevar(s::Expr, pvars)
    if !(exprhead(s) == :(::))
        error("Syntax for specifying a slot is x::\$predicate, where predicate is a boolean function or a type")
    end

    name = arguments(s)[1]
    name ∉ pvars && push!(pvars, name)
    return :(PatVar($(QuoteNode(name)), -1, $(arguments(s)[2])))
end
function makevar(name::Symbol, pvars) 
    name ∉ pvars && push!(pvars, name)
    PatVar(name)
end


# treat as a literal
"""
You can use `makepattern` to recursively convert an `Expr` (or
any type satisfying [`Metatheory.TermInterface`](@ref)) into an expression that
will build an [`AbstractPat`](@ref) if evaluated.
"""
makepattern(x::Symbol, pvars, mod=@__MODULE__) = makevar(x, pvars)
makepattern(x, pvars, mod=@__MODULE__) = x
function makepattern(ex::Expr, pvars, mod=@__MODULE__)
    head = exprhead(ex)
    op = operation(ex)
    args = arguments(ex)
    istree(op) && throw(Meta.ParseError("Unsupported pattern syntax $ex"))
    op = op isa Symbol ? QuoteNode(op) : op

    
    if head === :call
        patargs = map(i -> makepattern(i, pvars, mod), args) # recurse
        return :(PatTerm(:call, $op, [$(patargs...)], $mod))
    elseif head === :(...)
        return makesegment(args[1], pvars)
    elseif head === :(::)
        return makevar(ex, pvars)
    elseif head === :ref 
        # getindex 
        patargs = map(i -> makepattern(i, pvars, mod), args)
        return :(PatTerm(:ref, getindex, [$(patargs...)], $mod))
    elseif head === :$
        return esc(args[1])
    elseif head isa Symbol
        h = Meta.quot(head)
        patargs = map(i -> makepattern(i, pvars, mod), args)
        return :(PatTerm($h, $h, [$(patargs...)], $mod))
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
    pvars = Symbol[]
    lhs = makepattern(l, pvars, __module__)
    rhs = RuleType <: SymbolicRule ? makepattern(r, [], __module__) : r

    if RuleType == DynamicRule
        rhs = rewrite_rhs(r)
        params = Expr(:tuple, :_lhs_expr, :_subst, :_egraph, pvars...)
        rhs =  :($(esc(params)) -> $(esc(rhs)))
    end

    return quote 
        $(__source__)
        println($(esc(lhs)))
        ($RuleType)($(QuoteNode(e)), $(esc(lhs)), $rhs)
    end
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


# TODO ADD ORIGINAL CODE OF PREDICATE TO PATVAR

to_expr(x::PatVar) = x.predicate == alwaystrue ? x.name : Expr(:(::), x.name, x.predicate)
    
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