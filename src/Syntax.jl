module Syntax
using Metatheory.Patterns
using Metatheory.Rules
using TermInterface

using Metatheory: alwaystrue, cleanast, ematch_compile

export @rule
export @theory
export @slots
export @capture


# FIXME this thing eats up macro calls!
"""
Remove LineNumberNode from quoted blocks of code
"""
rmlines(e::Expr) = Expr(e.head, map(rmlines, filter(x -> !(x isa LineNumberNode), e.args))...)
rmlines(a) = a

function makesegment(s::Expr, pvars, mod)
  if s.head != :(::)
    error("Syntax for specifying a segment is ~~x::\$predicate, where predicate is a boolean function or a type")
  end

  name, predicate = children(s)
  if !(predicate isa Symbol) && isdefined(mod, predicate)
    error("Invalid predicate in $s. Predicates must be names of functions or types defined in current module.")
  end
  name ∉ pvars && push!(pvars, name)
  return PatSegment(name, -1, getfield(mod, predicate))
end

function makesegment(name::Symbol, pvars, mod)
  name ∉ pvars && push!(pvars, name)
  PatSegment(name)
end

function makevar(s::Expr, pvars, mod)
  if s.head != :(::)
    throw(
      DomainError(
        s,
        "Syntax for specifying a slot is ~x::\$predicate, where predicate is a boolean function or a type",
      ),
    )
  end

  name, predicate = children(s)
  if !(predicate isa Symbol) && isdefined(mod, predicate)
    error("Invalid predicate in $s. Predicates must be names of functions or types defined in current module.")
  end
  name ∉ pvars && push!(pvars, name)
  return PatVar(name, -1, getfield(mod, predicate))
end

function makevar(name::Symbol, pvars, mod)
  name ∉ pvars && push!(pvars, name)
  PatVar(name)
end


# Make a dynamic rule right hand side
function makeconsequent(expr::Expr)
  if iscall(expr)
    op = operation(expr)
    args = arguments(expr)
    if op === :(~)
      let v = args[1]
        if v isa Symbol
          v
        elseif v isa Expr && iscall(v) && operation(v) === :(~)
          n = v.args[2]
          @assert n isa Symbol
          n
        else
          throw(DomainError(v, "Could not parse RHS, unknown expression"))
        end
      end
    else
      Expr(expr.head, makeconsequent(op), map(makeconsequent, args)...)
    end
  else
    Expr(expr.head, map(makeconsequent, children(expr))...)
  end
end

makeconsequent(x) = x
# treat as a literal
function makepattern(x, pvars, slots, mod, splat = false)
  if x in slots
    splat ? makesegment(x, pvars, mod) : makevar(x, pvars, mod)
  elseif x isa Symbol
    PatLiteral(getfield(mod, x))
  elseif x isa QuoteNode
    PatLiteral(x.value)
  else
    PatLiteral(x)
  end
end

function makepattern(ex::Expr, pvars, slots, mod = @__MODULE__, splat = false)
  h = head(ex)

  if iscall(ex)
    op = operation(ex)
    isexpr(op) && (op = makepattern(op, pvars, slots, mod))
    # Optionally quote function objects
    args = arguments(ex)
    if op === :(~) # is a variable or segment
      let v = args[1]
        if v isa Expr && iscall(v) && operation(v) === :(~)
          # matches ~~x::predicate or ~~x::predicate...
          makesegment(v.args[2], pvars, mod)
        elseif splat
          # matches ~x::predicate...
          makesegment(v, pvars, mod)
        else
          makevar(v, pvars, mod)
        end
      end
    else# Matches a term
      patargs = map(i -> makepattern(i, pvars, slots, mod), args) # recurse
      op_obj = if op isa Symbol && isdefined(mod, op)
        getfield(mod, op)
      elseif op isa Expr
        makepattern(op, pvars, slots, mod, false)
      else
        op
      end
      PatExpr(iscall(ex), op_obj, patargs)
    end

  elseif h === :...
    makepattern(ex.args[1], pvars, slots, mod, true)
  elseif h == :(::) && ex.args[1] in slots
    splat ? makesegment(ex, pvars) : makevar(ex, pvars, mod)
  elseif h === :$
    ex.args[1]
  else
    # @show "PORCO DIO!"
    patargs = map(i -> makepattern(i, pvars, slots, mod), ex.args) # recurse
    PatExpr(false, h, patargs)
  end
end

function rule_sym_map(ex::Expr)
  h = iscall(ex) ? operation(ex) : head(ex)
  if h == :(-->) || h == :(→)
    RewriteRule
  elseif h == :(=>)
    DynamicRule
  elseif h == :(==)
    EqualityRule
  elseif h == :(!=) || h == :(≠)
    UnequalRule
  else
    error("Cannot parse rule with operator '$h'")
  end
end
rule_sym_map(ex) = error("Cannot parse rule from $ex")

"""
    rewrite_rhs(expr::Expr)

Rewrite the `expr` by dealing with `:where` if necessary.
The `:where` is rewritten from, for example, `~x where f(~x)` to `f(~x) ? ~x : nothing`.
"""
function rewrite_rhs(ex::Expr)
  if ex.head == :where
    rhs, predicate = children(ex)
    return :($predicate ? $rhs : nothing)
  end
  ex
end
rewrite_rhs(x) = x


function addslots(expr, slots)
  if expr isa Expr
    if expr.head === :macrocall &&
       expr.args[1] in [Symbol("@rule"), Symbol("@capture"), Symbol("@slots"), Symbol("@theory")]
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
  slots = args[1:(end - 1)]
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
julia> r = @rule sin(~x) --> cos(~x)
sin(~x) --> cos(~x)

julia> r(:(sin(1+a)))
:(cos((1 + a)))
```

A rule with 2 segment variables

```julia
julia> r = @rule sin(~x + ~y) --> sin(~x)*cos(~y) + cos(~x)*sin(~y)
sin(~x + ~y) --> sin(~x) * cos(~y) + cos(~x) * sin(~y)

julia> r(:(sin(a + b)))
:(cos(a)*sin(b) + sin(a)*cos(b))
```

A rule that matches two of the same expressions:

```julia
julia> r = @rule sin(~x)^2 + cos(~x)^2 --> 1
sin(~x) ^ 2 + cos(~x) ^ 2 --> 1

julia> r(:(sin(2a)^2 + cos(2a)^2))
1

julia> r(:(sin(2a)^2 + cos(a)^2))
# nothing
```

A rule without `~`
```julia
julia> r = @slots x y z @rule x(y + z) --> x*y + x*z
x(y + z) --> x*y + x*z
```

**Segment**:
A Segment variable matches zero or more expressions in the function call.
Segments may be written by splatting slot variables (`~x...`).

_Example:_

```julia
julia> r = @rule f(~xs...) --> g(~xs...);
julia> r(:(f(1, 2, 3)))
:(g(1,2,3))
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

julia> r = @rule sin(~~x + ~y::two_πs + ~~z) => :(sin(\$(Expr(:call, :+, ~~x..., ~~z...))))
sin(~(~x) + ~(y::two_πs) + ~(~z)) --> sin(+(~(~x)..., ~(~z)...))

julia> r(:(sin(a+\$(3π))))

julia> r(:(sin(a+\$(6π))))
:(sin(+a))

julia> r(sin(a+6π+c))
:(sin(a + c))
```

Predicate function gets an array of values if attached to a segment variable (`~x...`).

For the predicate over the whole rule, use `@rule <LHS> => <RHS> where <predicate>`:

```
julia> predicate(x) = x === a;

julia> r = @rule ~x => ~x where f(~x);

julia> r(a)
a

julia> r(b) === nothing
true
```

Note that this is syntactic sugar and that it is the same as
`@rule ~x => f(~x) ? ~x : nothing`.

**Compatibility**:
Segment variables may still be written as (`~~x`), and slot (`~x`) and segment (`~x...` or `~~x`) syntaxes on the RHS will still substitute the result of the matches.
See also: [`@capture`](@ref), [`@slots`](@ref)
"""
macro rule(args...)
  length(args) >= 1 || ArgumentError("@rule requires at least one argument")
  slots = args[1:(end - 1)]
  expr = args[end]

  e = macroexpand(__module__, expr)
  e = rmlines(e)
  RuleType = rule_sym_map(e)

  l, r = iscall(e) ? arguments(e) : children(e)
  pvars = Symbol[]
  lhs::AbstractPat = makepattern(l, pvars, slots, __module__)
  ppvars = Patterns.patvars(lhs)

  ematcher_right_expr = nothing

  rhs = RuleType <: SymbolicRule ? makepattern(r, [], slots, __module__) : r

  if RuleType <: BidirRule
    ppvars = ppvars ∪ Patterns.patvars(rhs)
    setdebrujin!(lhs, pvars)
    setdebrujin!(rhs, pvars)
    ematcher_right_expr = esc(ematch_compile(rhs, ppvars, -1))
  else
    setdebrujin!(lhs, ppvars)
  end
  ematcher_left_expr = esc(ematch_compile(lhs, ppvars, 1))

  # @show pvars
  # @show ppvars

  if RuleType == DynamicRule
    rhs_rewritten = rewrite_rhs(r)
    rhs_consequent = makeconsequent(rhs_rewritten)
    params = Expr(:tuple, :_lhs_expr, :_egraph, pvars...)
    rhs = :($(esc(params)) -> $(esc(rhs_consequent)))
    return quote
      $(__source__)
      DynamicRule($lhs, $rhs, $ematcher_left_expr, $(QuoteNode(rhs_consequent)))
    end
  end

  if RuleType <: BidirRule
    return quote
      $(__source__)
      ($RuleType)($lhs, $rhs, $ematcher_left_expr, $ematcher_right_expr)
    end
  end

  quote
    $(__source__)
    ($RuleType)($lhs, $rhs, $ematcher_left_expr)
  end
end


# Theories can just be vectors of rules!
"""
    @theory [SLOTS...] begin (LHS operator RHS)... end

Syntax sugar to define a vector of rules in a nice and readable way. Can use `@slots` or have the slots 
as the first arguments:

```
julia> t = @theory x y z begin 
    x * (y + z) --> (x * y) + (x * z)
    x + y       ==  (y + x)
    #...
end;
```

Is the same thing as writing

```
julia> v = [
    @rule x y z  x * (y + z) --> (x * y) + (x * z)
    @rule x y x + y == (y + x)
    #...
];
```
"""
macro theory(args...)
  length(args) >= 1 || ArgumentError("@theory requires at least one argument")
  slots = args[1:(end - 1)]
  expr = args[end]

  e = macroexpand(__module__, expr)
  e = rmlines(e)
  # e = interp_dollar(e, __module__)

  if e.head == :block
    ee = Expr(:vect, map(x -> addslots(:(@rule($x)), slots), children(e))...)
    esc(ee)
  else
    error("theory is not in form begin a => b; ... end")
  end
end



"""
    @capture ex pattern
Uses a `Rule` object to capture an expression if it matches the `pattern`. Returns `true` and injects
slot variable match results into the calling scope when the `pattern` matches, otherwise returns false. The
rule language for specifying the `pattern` is the same in @capture as it is in `@rule`. Contextual matching
is not yet supported
```julia
julia> @syms a; ex = a^a;
julia> if @capture ex (~x)^(~x)
           @show x
       elseif @capture ex 2(~y)
           @show y
       end;
x = a
```
See also: [`@rule`](@ref)
"""
macro capture(args...)
  length(args) >= 2 || ArgumentError("@capture requires at least two arguments")
  slots = args[1:(end - 2)]
  ex = args[end - 1]
  lhs = args[end]
  @show lhs
  lhs = macroexpand(__module__, lhs)
  lhs = rmlines(lhs)

  @show lhs

  pvars = Symbol[]
  lhs = makepattern(lhs, pvars, slots, __module__)
  @show lhs
  bind = Expr(
    :block,
    map(key -> :($(esc(key)) = getindex(__MATCHES__, findfirst((==)($(QuoteNode(key))), $pvars))), pvars)...,
  )
  ret = quote
    $(__source__)
    rule = DynamicRule($lhs, (_lhs_expr, _egraph, pvars...) -> pvars, (x...) -> nothing)
    __MATCHES__ = rule($(esc(ex)))
    if __MATCHES__ !== nothing
      $bind
      true
    else
      false
    end
  end
  @show ret
  ret
end


end
