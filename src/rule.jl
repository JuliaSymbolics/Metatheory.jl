mutable struct Rule
    left::Any
    right::Any
    expr::Expr # original expression
    mode::Symbol # can be :rewrite or :dynamic
end

# operator symbols for simple term rewriting
const rewrite_syms = [:(=>)]
# operator symbols for regular pattern matching rules, "dynamic rules"
# that eval the right side at reduction time.
# might be used to implement big step semantics
const dynamic_syms = [:(|>)]

const raw_syms = [:(↦)]

"""
Construct a `Rule` from a quoted expression.
You can also use the [`@rule`] macro to
create a `Rule`.
## Symbolic Rules

Rules defined as `left_hand => right_hand` are
called `symbolic` rules. Application of a `symbolic` Rule
is a replacement of the `left_hand` pattern with
the `right_hand` substitution, with the correct instantiation
of pattern variables. Function call symbols are not treated as pattern
variables, all other identifiers are treated as pattern variables.
Literals such as `5, :e, "hello"` are not treated as pattern
variables.

## Dynamic Rules

Rules defined as `left_hand |> right_hand` are
called `dynamic` rules. Dynamic rules behave like anonymous functions.
Instead of a symbolic substitution, the right hand of
a dynamic `|>` rule is evaluated during rewriting:
matched values are bound to pattern variables as in a
regular function call. This allows for dynamic computation
of

## Type Assertions

Type assertions are supported in the left hand of rules
to match and access literal values both when using classic
rewriting and EGraph based rewriting.
To use a type assertion pattern, add `::T` after
a pattern variable in the `left_hand` of a rule.

---

## Examples

Symbolic rule
```julia
Rule(:(a * b => b * a))
```

Dynamic rules computing the actual multiplication of two numbers on
a match
```julia
Rule(:(a::Number * b::Number |> a*b))
```
"""
function Rule(e::Expr)
    e = rmlines(e)
    mode = :undef
    mode = getfunsym(e)
    l, r = e.args[iscall(e) ? (2:3) : (1:2)]

    if mode ∈ dynamic_syms # right hand execution, dynamic rules in egg
        mode = :dynamic
    elseif mode ∈ rewrite_syms # right side is quoted, symbolic replacement
        mode = :rewrite
    elseif mode ∈ raw_syms
        mode = :raw
    else
        error(`rule "$e" is not in valid form.\n`)
    end

    Rule(l, r, e, mode)
end

macro rule(e)
    Rule(e)
end

# string representation of the rule
function Base.show(io::IO, x::Rule)
    println(io, "Rule(:(", x.expr, "))")
end
