# Rules and Theories


## Theories are Collections and Composable

Theories are just collections, precisely *vectors of the `Rule` object*, and can
be composed as regular Julia collections. The most
useful way of composing theories is unioning
them with the '∪' operator.
You are not limited to composing theories, you can
manipulate and create them at both runtime and compile time
as regular vectors.

```@example 2
using Metatheory
using Metatheory.EGraphs
using Metatheory.Library

comm_monoid = commutative_monoid(:(*), 1);
comm_group = @theory begin
    a + 0 => a
    a + b => b + a
    a + inv(a) => 0 # inverse
    a + (b + c) => (a + b) + c
end
distrib = @theory begin
    a * (b + c) => (a * b) + (a * c)
end
t = comm_monoid ∪ comm_group ∪ distrib
```

## Type Assertions and Dynamic Rules

You can use type assertions in the left hand of rules
to match and access literal values both when using
classic rewriting and EGraph based rewriting.

You can also use **dynamic rules**, defined with the `|>`
operator, to dynamically compute values in the right hand of expressions.
Dynamic rules, are similar to anonymous functions. Instead of a symbolic
substitution, the right hand of a dynamic `|>` rule is evaluated during
rewriting: the values that produced a match are bound to the pattern variables.

```@example 2
fold_mul = @theory begin
    a::Number * b::Number |> a*b
end
t = comm_monoid ∪ fold_mul
@areequal t (3*4) 12
```


## Escaping

You can escape values in the left hand side of rules using `$` just
as you would do with the regular [quoting/unquoting](https://docs.julialang.org/en/v1/manual/metaprogramming/) mechanism.


```@example 2
example = @theory begin
    a + $(3+2) |> :something
end
```

## Patterns

```@autodocs
Modules = [Rules]
Pages = ["patterns.jl", "patterns_syntax.jl"]
```

## Rules 

```@autodocs
Modules = [Rules]
Pages = ["rule_types.jl", "rule_dsl.jl"]
```
