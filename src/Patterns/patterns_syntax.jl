
# ======================= READING ====================

# Resolve `GlobalRef` instances to literals.
resolve(gr::GlobalRef) = getproperty(gr.mod, gr.name)
resolve(gr) = gr

# treat as a literal
Pattern(x, mod=@__MODULE__, resolve_fun=false) = esc(x)

function Pattern(ex::Expr, mod=@__MODULE__, resolve_fun=false)
    ex = cleanast(ex)

    head = exprhead(ex)
    op = operation(ex)
    args = arguments(ex)

    istree(op) && throw(Meta.ParseError("Unsupported pattern syntax $ex"))

    
    if head === :call
        if operation(ex) === :(~) # is a variable or segment
            if args[1] isa Expr && operation(args[1]) == :(~)
                makesegment(arguments(args[1])[1])
            else
                makeslot(args[1])
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
        return args[1]
    else 
        throw(Meta.ParseError("Unsupported pattern syntax $ex"))
    end
end

function makesegment(s::Expr)
    if !(exprhead(s) == :(::))
        error("Syntax for specifying a segment is ~~x::\$predicate, where predicate is a boolean function")
    end

    name = arguments(s)[1]

    # TODO get the

    PatSegment(name, arguments[2])
end


function Pattern(x::Symbol, mod=@__MODULE__, resolve_fun=false)
    PatVar(x)
end

function Pattern(p::Pattern, mod=@__MODULE__, resolve_fun=false)
    p 
end

macro pat(ex)
    Pattern(ex, __module__, false)
end

macro pat(ex, resolve_fun::Bool)
    Pattern(ex, __module__, resolve_fun)
end
