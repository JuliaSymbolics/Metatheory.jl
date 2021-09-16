module SUSyntax
using Metatheory.Rules 
using Metatheory.Patterns
using Metatheory.Util
using TermInterface

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
        error("Syntax for specifying a segment is ~~x::\$predicate, where predicate is a boolean function")
    end

    name = arguments(s)[1]
    p = makepredicate(arguments(s)[2], mod)
    PatSegment(name, -1, p)
end
makesegment(s::Symbol, mod) = PatSegment(s)

function makevar(s::Expr, mod::Module)
    if !(exprhead(s) == :(::))
        error("Syntax for specifying a slot is ~x::\$predicate, where predicate is a boolean function")
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

# Make a dynamic rule right hand side
function makeconsequent(expr::Expr)
    head = exprhead(expr)
    args = arguments(expr)
    op = operation(expr)
    if head === :call
        if op === :(~)
            if args[1] isa Symbol
                return args[1]
            elseif args[1] isa Expr && operation(args[1]) == :(~)
                n = arguments(args[1])[1]
                @assert n isa Symbol
                return n
            else
                error("Error when parsing right hand side")
            end
        else
            return Expr(head, makeconsequent(op), 
                map(makeconsequent, args)...)
        end
    else
        return Expr(head, map(makeconsequent, args)...)
    end
end

makeconsequent(x) = x

# treat as a literal
Pattern(x, mod=@__MODULE__, resolve_fun=false) = x
Pattern(x::QuoteNode, mod=@__MODULE__, resolve_fun=false) = x.value isa Symbol ? x.value : x

function Pattern(ex::Expr, mod=@__MODULE__, resolve_fun=false)
    ex = cleanast(ex)

    head = exprhead(ex)
    op = operation(ex)
    args = arguments(ex)

    istree(op) && (op = Pattern(op, mod, resolve_fun))
    #throw(Meta.ParseError("Unsupported pattern syntax $ex"))

    
    if head === :call
        if operation(ex) === :(~) # is a variable or segment
            if args[1] isa Expr && operation(args[1]) == :(~)
                makesegment(arguments(args[1])[1], mod)
            else
                makevar(args[1], mod)
            end
        else # is a term
            if resolve_fun && op isa Symbol
                op = resolve(GlobalRef(mod, op))
            end
            patargs = map(i -> Pattern(i, mod, resolve_fun), args) # recurse
            PatTerm(head, op, patargs)
        end
    elseif head === :ref 
        # getindex 
        PatTerm(head, resolve_fun ? getindex : :getindex,
            map(i -> Pattern(i, mod, resolve_fun), args))
    elseif head === :$
        return mod.eval(args[1])
    else 
        throw(Meta.ParseError("Unsupported pattern syntax $ex"))
    end
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

"""
    rewrite_rhs(expr::Expr)

Rewrite the `expr` by dealing with `:where` if necessary.
The `:where` is rewritten from, for example, `~x where f(~x)` to `f(~x) ? ~x : nothing`.
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


include("rule.jl")


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