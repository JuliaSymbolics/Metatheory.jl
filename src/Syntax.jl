module Syntax
using Metatheory.Patterns
using Metatheory.Rules
using TermInterface

using Metatheory:alwaystrue, cleanast, binarize

export to_expr
export @rule
export @theory
export @slots


# FIXME this thing eats up macro calls!
"""
Remove LineNumberNode from quoted blocks of code
"""
rmlines(e::Expr) = Expr(e.head, map(rmlines, filter(x -> !(x isa LineNumberNode), e.args))...)
rmlines(a) = a


function makesegment(s::Expr, pvars)
    if !(exprhead(s) == :(::))
        error("Syntax for specifying a segment is ~~x::\$predicate, where predicate is a boolean function or a type")
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
        error("Syntax for specifying a slot is ~x::\$predicate, where predicate is a boolean function or a type")
    end

    name = arguments(s)[1]
    name ∉ pvars && push!(pvars, name)
    return :(PatVar($(QuoteNode(name)), -1, $(arguments(s)[2])))
end
function makevar(name::Symbol, pvars) 
    name ∉ pvars && push!(pvars, name)
    PatVar(name)
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
makepattern(x, pvars, slots, mod=@__MODULE__) = x in slots ? makevar(x, pvars) : x

function makepattern(ex::Expr, pvars, slots, mod=@__MODULE__, splat=false)
    head = exprhead(ex)
    op = operation(ex)
    args = arguments(ex)
    istree(op) && (op = makepattern(op, pvars, slots, mod))
    op = op isa Symbol ? QuoteNode(op) : op
    #throw(Meta.ParseError("Unsupported pattern syntax $ex"))

    
    if head === :call
        if operation(ex) === :(~) # is a variable or segment
            if args[1] isa Expr && operation(args[1]) == :(~)
                # matches ~~x::predicate or ~~x::predicate...
                return makesegment(arguments(args[1])[1], pvars)
            elseif splat
                # matches ~x::predicate...
                return makesegment(args[1], pvars)
            else
                return makevar(args[1], pvars)
            end
        else # is a term
            patargs = map(i -> makepattern(i, pvars, slots, mod), args) # recurse
            return :(PatTerm(:call, $op, [$(patargs...)], $mod))
        end
    elseif head === :... 
        makepattern(args[1], pvars, slots, mod, true)
    elseif head == :(::) && args[1] in slots
        return splat ? makesegment(ex, pvars) : makevar(ex, pvars)
    elseif head === :ref 
        # getindex 
        patargs = map(i -> makepattern(i, pvars, slots, mod), args) # recurse
        return :(PatTerm(:ref, getindex, [$(patargs...)], $mod))
    elseif head === :$
        return args[1]
    else 
        patargs = map(i -> makepattern(i, pvars, slots, mod), args) # recurse
        return :(PatTerm($(head isa Symbol ? QuoteNode(head) : head), $(op isa Symbol ? QuoteNode(op) : op), [$(patargs...)], $mod))
        # throw(Meta.ParseError("Unsupported pattern syntax $ex"))
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


function addslots(expr, slots)
    if expr isa Expr
        if expr.head === :macrocall && expr.args[1] in [Symbol("@rule"), Symbol("@capture"), Symbol("@slots"), Symbol("@theory")]
            Expr(:macrocall, expr.args[1:2]..., slots..., expr.args[3:end]...)
        else
            Expr(expr.head, addslots.(expr.args, (slots,))...)
        end
    else
        expr
    end
end


"""
    @slots [SLOTS...] ex
Declare SLOTS as slot variables for all `@rule` or `@capture` invocations in the expression `ex`.
_Example:_
```julia
julia> @slots x y z a b c Chain([
    (@rule x^2 + 2x*y + y^2 => (x + y)^2),
    (@rule x^a * y^b => (x*y)^a * y^(b-a)),
    (@rule +(x...) => sum(x)),
])
```
See also: [`@rule`](@ref), [`@capture`](@ref)
"""
macro slots(args...)
    length(args) >= 1 || ArgumentError("@slots requires at least one argument")
    slots = args[1:end-1]
    expr = args[end]

    return esc(addslots(expr, slots))
end


"""
    @rule [SLOTS...] LHS operator RHS

Creates an `AbstractRule` object. A rule object is callable, and takes an
expression and rewrites it if it matches the LHS pattern to the RHS pattern,
returns `nothing` otherwise. The rule language is described below.

LHS can be any possibly nested function call expression where any of the arugments can
optionally be a Slot (`~x`) or a Segment (`~x...`) (described below).

SLOTS is an optional list of symbols to be interpeted as slots or segments
directly (without using `~`).  To declare slots for several rules at once, see
the `@slots` macro.

If an expression matches LHS entirely, then it is rewritten to the pattern in
the RHS , whose local scope includes the slot matches as variables. Segment
(`~x`) and slot variables (`~~x`) on the RHS will substitute the result of the
matches found for these variables in the LHS.

**Rule operators**:
- `LHS => RHS`: create a `DynamicRule`. The RHS is *evaluated* on rewrite.
- `LHS --> RHS`: create a `RewriteRule`. The RHS is **not** evaluated but *symbolically substituted* on rewrite.
- `LHS == RHS`: create a `EqualityRule`. In e-graph rewriting, this rule behaves like `RewriteRule` but can go in both directions. Doesn't work in classical rewriting
- `LHS ≠ RHS`: create a `UnequalRule`. Can only be used in e-graphs, and is used to eagerly stop the process of rewriting if LHS is found to be equal to RHS.

**Slot**:

A Slot variable is written as `~x` and matches a single expression. `x` is the name of the variable. If a slot appears more than once in an LHS expression then expression matched at every such location must be equal (as shown by `isequal`).

_Example:_

Simple rule to turn any `sin` into `cos`:

```julia
julia> @syms a b c
(a, b, c)

julia> r = @rule sin(~x) => cos(~x)
sin(~x) => cos(~x)

julia> r(sin(1+a))
cos((1 + a))
```

A rule with 2 segment variables

```julia
julia> r = @rule sin(~x + ~y) => sin(~x)*cos(~y) + cos(~x)*sin(~y)
sin(~x + ~y) => sin(~x) * cos(~y) + cos(~x) * sin(~y)

julia> r(sin(a + b))
cos(a)*sin(b) + sin(a)*cos(b)
```

A rule that matches two of the same expressions:

```julia
julia> r = @rule sin(~x)^2 + cos(~x)^2 => 1
sin(~x) ^ 2 + cos(~x) ^ 2 => 1

julia> r(sin(2a)^2 + cos(2a)^2)
1

julia> r(sin(2a)^2 + cos(a)^2)
# nothing
```

A rule without `~`
```julia
julia> r = @slots x y z @rule x(y + z) => x*y + x*z
x(y + z) => x*y + x*z
```

**Segment**:
A Segment variable matches zero or more expressions in the function call.
Segments may be written by splatting slot variables (`~x...`).

_Example:_

This implements the distributive property of multiplication: `+(~ys...)` matches expressions
like `a + b`, `a+b+c` and so on. On the RHS `ys` presents as any old julia array.

```julia
julia> r = @rule ~x * +((~ys...)) => sum(map(y-> x * y, ys));
julia> r(2 * (a+b+c))
((2 * a) + (2 * b) + (2 * c))
```

A segment without `~`.
```julia
julia> r = @slots xs @rule min(xs...) => foldl(min, xs, Inf);
julia> r(min(a, b, c))
min(min(a, b), c)
```

**Predicates**:

There are two kinds of predicates, namely over slot variables and over the whole rule.
For the former, predicates can be used on both `~x` and `~~x` by using the `~x::f` or `~~x::f`.
Here `f` can be any julia function. In the case of a slot the function gets a single
matched subexpression, in the case of segment, it gets an array of matched expressions.

The predicate should return `true` if the current match is acceptable, and `false`
otherwise.

```julia
julia> two_πs(x::Number) = abs(round(x/(2π)) - x/(2π)) < 10^-9
two_πs (generic function with 1 method)

julia> two_πs(x) = false
two_πs (generic function with 2 methods)

julia> r = @rule sin(~~x + ~y::two_πs + ~~z) => sin(+(~~x..., ~~z...))
sin(~(~x) + ~(y::two_πs) + ~(~z)) => sin(+(~(~x)..., ~(~z)...))

julia> r(sin(a+3π))

julia> r(sin(a+6π))
sin(a)

julia> r(sin(a+6π+c))
sin((a + c))
```

Predicate function gets an array of values if attached to a segment variable (`~x...`).

For the predicate over the whole rule, use `@rule <LHS> => <RHS> where <predicate>`:

```
julia> @syms a b;

julia> predicate(x) = x === a;

julia> r = @rule ~x => ~x where f(~x);

julia> r(a)
a

julia> r(b) === nothing
true
```

Note that this is syntactic sugar and that it is the same as something like
`@rule ~x => f(~x) ? ~x : nothing`.

**Context**:

_In predicates_: Contextual predicates are functions wrapped in the `Contextual` type.
The function is called with 2 arguments: the expression and a context object
passed during a call to the Rule object (maybe done by passing a context to `simplify` or
a `RuleSet` object).

The function can use the inputs however it wants, and must return a boolean indicating
whether the predicate holds or not.

_In the consequent pattern_: Use `(@ctx)` to access the context object on the right hand side
of an expression.

**Compatibility**:
Segment variables may still be written as (`~~x`), and slot (`~x`) and segment (`~x...` or `~~x`) syntaxes on the RHS will still substitute the result of the matches.
See also: [`@capture`](@ref), [`@slots`](@ref)
"""
macro rule(args...)
    length(args) >= 1 || ArgumentError("@rule requires at least one argument")
    slots = args[1:end-1]
    expr = args[end]

    e = macroexpand(__module__, expr)
    e = rmlines(e)
    op = operation(e)
    RuleType = rule_sym_map(e)
    
    l, r = arguments(e)
    pvars = Symbol[]
    lhs = makepattern(l, pvars, slots, __module__)
    rhs = RuleType <: SymbolicRule ? makepattern(r, [], slots, __module__) : r

    if RuleType == DynamicRule
        rhs = rewrite_rhs(r)
        rhs = makeconsequent(rhs)
        params = Expr(:tuple, :_lhs_expr, :_subst, :_egraph, pvars...)
        rhs =  :($(esc(params)) -> $(esc(rhs)))
    end

    return quote
        $(__source__)
        ($RuleType)($(QuoteNode(expr)), $(esc(lhs)), $rhs)
    end
end


# Theories can just be vectors of rules!

macro theory(args...)
    length(args) >= 1 || ArgumentError("@rule requires at least one argument")
    slots = args[1:end-1]
    expr = args[end]

    e = macroexpand(__module__, expr)
    e = rmlines(e)
    # e = interp_dollar(e, __module__)

    if exprhead(e) == :block
        ee = Expr(:vect, map(x -> addslots(:(@rule($x)), slots), arguments(e))...)
        esc(ee)
    else
        error("theory is not in form begin a => b; ... end")
    end
end


# TODO ADD ORIGINAL CODE OF PREDICATE TO PATVAR

function to_expr(x::PatVar)
    if x.predicate == alwaystrue
        Expr(:call, :~, x.name)
    else
        Expr(:call, :~, Expr(:(::), x.name, x.predicate))
    end
end

to_expr(x::Any) = x

function to_expr(x::PatSegment)
    Expr(:call, :~, 
        if x.predicate == alwaystrue
        Expr(:call, :~, x.name)
    else
        Expr(:call, :~, Expr(:(::), x.name, x.predicate))
    end
    )
end

to_expr(x::PatSegment{typeof(alwaystrue)}) = 
    Expr(:call, :~, Expr(:call, :~, Expr(:call, :~, x.name)))
to_expr(x::PatSegment{T}) where {T <: Function} = 
    Expr(:call, :~, Expr(:call, :~, Expr(:(::), x.name, nameof(T))))
to_expr(x::PatSegment{<:Type{T}}) where T = 
    Expr(:call, :~, Expr(:call, :~, Expr(:(::), x.name, T)))

function to_expr(x::PatTerm) 
    pl = operation(x)
    similarterm(Expr, pl, arguments(x); exprhead=exprhead(x))
end


end

