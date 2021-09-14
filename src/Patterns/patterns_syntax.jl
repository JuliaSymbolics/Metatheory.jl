
# ======================= READING ====================

# Resolve `GlobalRef` instances to literals.
resolve(gr::GlobalRef) = getproperty(gr.mod, gr.name)
resolve(gr) = gr

# treat as a literal
Pattern(x, mod=@__MODULE__, resolve_fun=false) = x

function Pattern(ex::Expr, mod=@__MODULE__, resolve_fun=false)
    ex = cleanast(ex)

    head = exprhead(ex)
    op = operation(ex)
    args = arguments(ex)

    istree(op) && throw(Meta.ParseError("Unsupported pattern syntax $ex"))

    
    if head === :call
        if operation(ex) === :(~) # is a variable or segment
            if args[1] isa Expr && operation(args[1]) == :(~)
                makesegment(arguments(args[1])[1], mod)
            else
                makevar(args[1], mod)
            end
        else # is a term
            if resolve_fun && op isa Symbol
                op = resolve(GlobalRef(mod, f))
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

function makesegment(s::Expr, mod::Module)
    if !(exprhead(s) == :(::))
        error("Syntax for specifying a segment is ~~x::\$predicate, where predicate is a boolean function")
    end

    name = arguments(s)[1]
    p = makepredicate(arguments(s)[2], mod)
    PatSegment(name, -1, p)
end
makesegment(s::Symbol, mod) = PatSegment(name)

function makevar(s::Expr, mod::Module)
    if !(exprhead(s) == :(::))
        println(s)
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
        return Expr(head, makeconsequent(op), map(makeconsequent, args)...)
    end
end

makeconsequent(x) = x

function Pattern(p::Pattern, mod=@__MODULE__, resolve_fun=false)
    p 
end

macro pat(ex)
    Pattern(ex, __module__, false)
end

macro pat(ex, resolve_fun::Bool)
    Pattern(ex, __module__, resolve_fun)
end
