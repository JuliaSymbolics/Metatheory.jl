# Rules and Theories Syntax

# Rule Syntax for Classical Rewriting

| Kind            | Supported in Left Hand Side                                                                                                                                                                                   | Operator | Supported in Right Hand Side                                                                                                                                                         |
|-----------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Symbolic  Rule  | `x`  (pattern variables) ``\\`` `:foo` (symbol literals) ``\\`` `x::Type` (type assertions) ``\\`` `$(2 + 3)` (unquoting) ``\\`` `a...` (pattern variable destructuring, matches many subterms as a tuple) ``\\``  Other literals are supported. | `=>`     | `x` (pattern variables) ``\\`` `:foo`(symbol literals) ``\\`` `a...` (pattern variable destructuring) ``\\``  `$(2 + 3)` (unquoting) ``\\`` Other literals are supported.                                           |
| Dynamic Rule    | Same as above                                                                                                                                                                                                  | `\|>`    | Dynamic rules can execute all valid Julia code. The pattern variables  that matched are available (bound) in the r.h.s.. Other global variables  in the execution module are bound. An additional variable `_lhs_expr` is bound, referring to the left hand side that matched the rule.  |
| Equational Rule | Unsupported                                                                                                                                                                                                    | `==`     | Unsupported                                                                                                                                                                          |

# Rule Syntax for EGraphs Rewriting

| Kind            | Supported in  Left Hand Side                                                                                                                                                                                         | Operator | Supported in Right Hand Side                                                                                                                                                                                                                                                                                                                                                                                   |
|-----------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Symbolic  Rule  | `x`  (pattern variables) ``\\`` `:foo` (symbol literals) ``\\`` `x::Type` (type assertions) ``\\`` `$(2 + 3)` (unquoting) ``\\``  Other literals are supported. **Pattern variable destructuring is not supported**. | `=>`     | `x` (pattern variables) ``\\`` `:foo`(symbol literals) ``\\``  `$(2 + 3)` (unquoting) ``\\`` Other literals are supported.                                                                                                                                                                                                                                                                                                                    |
| Dynamic Rule    | Same as above                                                                                                                                                                                                        | `\|>`    | Dynamic rules execute valid Julia code. The pattern variables  that matched are available (bound) in the r.h.s.. Other global variables  in the execution module are bound. An additional variable `_lhs_expr` is bound,  referring to the left hand side that matched the rule.  **NOTE**: additionally, the `_egraph` variable is bound,  referring to the current `EGraph` on which rewriting is happening. |
| Equational Rule | Same as Symbolic Rules.                                                                                                                                                                                              | `==`     | Same as left hand side of symbolic rules.                                                                                                                                                                                                                                                                                                                                                                      |


## Theories are Collections and Composable

Theories are just collections, precisely *vectors of the `Rule` object*, and can
be composed as regular Julia collections. The most
useful way of composing theories is unioning
them with the '∪' operator.
You are not limited to composing theories, you can
manipulate and create them at both runtime and compile time
as regular vectors.

```julia
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

```julia
fold_mul = @theory begin
    a::Number * b::Number |> a*b
end
t = comm_monoid ∪ fold_mul
@areequal t (3*4) 12
```


## Escaping

You can escape values in the left hand side of rules using `$` just
as you would do with the regular [quoting/unquoting]() mechanism.


```julia
example = @theory begin
    a + $(3+2) |> :something
end
```

Becomes
```
1-element Vector{Rule}:
 Rule(:(a + 5 |> :something))
```
