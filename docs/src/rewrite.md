# Classical Term Rewriting

## Rule-based rewriting

Rewrite rules match and transform an expression. A rule is written using either
the `@rule` or `@theory` macros. It creates a callable `Rule` object.

### Basics of rule-based term rewriting in Metatheory.jl

**NOTE:** for a real world use case using mathematical constructs, please refer
to [SymbolicUtils.jl](https://github.com/JuliaSymbolics/SymbolicUtils.jl). SU
provides optimized types for mathematical expressions, code generation and a
polished set of rules for simplification.

Here is a simple symbolic rewrite rule, that uses formula for the double angle of the sine function:

```julia:rewrite1
using Metatheory

r1 = @rule sin(2(~x)) --> 2sin(~x)*cos(~x)

expr = :(sin(2z))
r1(expr)
```

The `@rule` macro takes a pair of patterns  -- the _matcher_ and the _consequent_ (`@rule matcher OPERATOR consequent`). If an expression matches the matcher pattern, it is rewritten to the consequent pattern. `@rule` returns a callable object that applies the rule to an expression. There are different kinds of rule in Metatheory.jl:

**Rule operators**:
- `LHS => RHS`: create a `DynamicRule`. The RHS is *evaluated* on rewrite.
- `LHS --> RHS`: create a `RewriteRule`. The RHS is **not** evaluated but *symbolically substituted* on rewrite.
- `LHS == RHS`: create a `EqualityRule`. In e-graph rewriting, this rule behaves like `RewriteRule` but can go in both directions. Doesn't work in classical rewriting.
- `LHS ≠ RHS`: create a `UnequalRule`. Can only be used in e-graphs, and is used to eagerly stop the process of rewriting if LHS is found to be equal to RHS.


You can use **dynamic rules**, defined with the `=>`
operator, to dynamically compute values in the right hand of expressions. This is the default behaviour of rules in [SymbolicUtils.jl](https://github.com/JuliaSymbolics/SymbolicUtils.jl)
Dynamic rules, are similar to anonymous functions. Instead of a symbolic
substitution, the right hand of a dynamic `=>` rule is evaluated during
rewriting: the values that produced a match are bound to the pattern variables.

`~x` in the example is what is a **slot variable** (or *pattern* variable) named `x`. In a matcher pattern, slot variables are placeholders that match exactly one expression. When used on the consequent side, they stand in for the matched expression. If a slot variable appears twice in a matcher pattern, **in classical rewriting** all corresponding matches must be equal (as tested by `Base.isequal` function). Hence this rule says: if you see something added to itself, make it twice of that thing, and works as such.

If you try to apply this rule to an expression with triple angle, it will return `nothing` -- this is the way a rule signifies failure to match.
```julia:rewrite2
r1(:(sin(3z))) === nothing
```

Slot variable (matcher) is not necessary a single variable

```julia:rewrite3
r1(:(sin(2*(w-z))))
```

but it must be a single expression

```julia:rewrite4
r1(:(sin(2*(w+z)*(α+β)))) === nothing
```

Rules are of course not limited to single slot variable

```julia:rewrite5
r2 = @rule sin(~x + ~y) --> sin(~x)*cos(~y) + cos(~x)*sin(~y);

r2(:(sin(α+β)))
```

If you want to match a variable number of subexpressions at once, you will need a **segment variable**. `~xs...` in the following example is a segment variable:

```julia:rewrite6
@rule(+(~xs...) => xs)(:(x + y + z))
```

`~xs` is a vector of subexpressions matched. You can use it to construct something more useful:

```julia:rewrite7
r3 = @rule *(~ys...)^~x => :((*)($(map(y-> :($y^$x), ys)...)));

r3(:((w*w*α*β)^2))
```

### Predicates for matching

Matcher pattern may contain slot variables with attached predicates, written as `~x::p` where `p` is either

- A function that takes a matched expression and returns a boolean value. Such a slot will be considered a match only if `p` returns true.
- A Julia type. Will be considered a match if and only if the value matching against `x` has a type that is a subtype of `p` (`typeof(x) <: p`)

Similarly `~x::g...` is a way of attaching a predicate `g` to a segment variable. In the case of segment variables `g` gets a vector of 0 or more expressions and must return a boolean value. If the same slot or segment variable appears twice in the matcher pattern, then at most one of the occurance should have a predicate.

For example,

```julia:pred1
r = @rule +(~x, ~y::(ys->iseven(length(ys)))...) => "odd terms";

@show r(:(a + b + c + d))
@show r(:(b + c + d))
@show r(:(b + c + b))
@show r(:(a + b))
```


### Declaring Slots

Slot variables can be declared without the `~` using the `@slots` macro

```julia:slots1
@slots x y @rule sin(x + y) => sin(x)*cos(y) + cos(x)*sin(y);
```

This works for segments as well:

```julia:slots2
@slots xs @rule(+(~xs...) => xs);
```

The `@slots` macro is superfluous for the `@rule`, `@capture` and `@theory` macros.
Slot variables may be declared directly as the first arguments to those macros:

```julia:slots3
@rule x y sin(x + y) => sin(x)*cos(y) + cos(x)*sin(y);
```

### Theories

In almost all use cases, it is practical to define many rules grouped together.
A set of rewrite rules and equalities is called a *theory*, and can be defined with the
`@theory` macro. This macro is just syntax sugar to define vectors of rules in a nice and readable way. 


```julia
t = @theory x y z begin 
    x * (y + z) --> (x * y) + (x * z)
    x + y       ==  (y + x)
    #...
end;
```

Is the same thing as writing

```julia
v = [
    @rule x y z  x * (y + z) --> (x * y) + (x * z)
    @rule x y x + y == (y + x)
    #...
];
```

Theories are just collections and
can be composed as regular Julia collections. The most
useful way of composing theories is unioning
them with the '∪' operator.
You are not limited to composing theories, you can
manipulate and create them at both runtime and compile time
as regular vectors.

```julia
using Metatheory
using Metatheory.Library

comm_monoid = @commutative_monoid (*) 1
comm_group = @theory a b c begin
    a + 0 --> a
    a + b --> b + a
    a + inv(a) --> 0 # inverse
    a + (b + c) --> (a + b) + c
end
distrib = @theory a b c begin
    a * (b + c) => (a * b) + (a * c)
end
t = comm_monoid ∪ comm_group ∪ distrib
```

## Composing rewriters

Rules may be *chained together* into more
sophisticated rewirters to avoid manual application of the rules. A rewriter is
any callable object which takes an expression and returns an expression or
`nothing`. If `nothing` is returned that means there was no changes applicable
to the input expression. The Rules we created above are rewriters.

The `Metatheory.Rewriters` module contains some types which create and transform
rewriters.

- `Empty()` is a rewriter which always returns `nothing`
- `Chain(itr)` chain an iterator of rewriters into a single rewriter which applies
   each chained rewriter in the given order.
   If a rewriter returns `nothing` this is treated as a no-change.
- `RestartedChain(itr)` like `Chain(itr)` but restarts from the first rewriter once on the
   first successful application of one of the chained rewriters.
- `IfElse(cond, rw1, rw2)` runs the `cond` function on the input, applies `rw1` if cond
   returns true, `rw2` if it retuns false
- `If(cond, rw)` is the same as `IfElse(cond, rw, Empty())`
- `Prewalk(rw; threaded=false, thread_cutoff=100)` returns a rewriter which does a pre-order 
   (*from top to bottom and from left to right*) traversal of a given expression and applies 
   the rewriter `rw`. `threaded=true` will use multi threading for traversal.
   Note that if `rw` returns `nothing` when a match is not found, then `Prewalk(rw)` will
   also return nothing unless a match is found at every level of the walk. If you are
   applying multiple rules, then `Chain` already has the appropriate passthrough behavior.
   If you only want to apply one rule, then consider using `PassThrough`.
   `thread_cutoff` 
   is the minimum number of nodes in a subtree which should be walked in a threaded spawn.
- `Postwalk(rw; threaded=false, thread_cutoff=100)` similarly does post-order 
   (*from left to right and from bottom to top*) traversal.
- `Fixpoint(rw)` returns a rewriter which applies `rw` repeatedly until there are no changes to be made.
- `FixpointNoCycle` behaves like `Fixpoint` but instead it applies `rw` repeatedly only while it is returning new results.
- `PassThrough(rw)` returns a rewriter which if `rw(x)` returns `nothing` will instead
   return `x` otherwise will return `rw(x)`.

### Chaining rewriters

Several rules may be chained to give chain of rules. Chain is an array of rules which are subsequently applied to the expression.
Important feature of `Chain` is that it returns the expression instead of `nothing` if it doesn't change the expression
It is important to notice, that chain is ordered, so if rules are in different order it wouldn't work the same as in earlier example


One way to circumvent the problem of order of applying rules in chain is to use
`RestartedChain`, it restarts the chain after each successful application of a
rule, so after a rule is hit it (re)starts again and it can apply all the other
rules to the resulting expression. You can also use `Fixpoint` to apply the
rules until there are no changes.

