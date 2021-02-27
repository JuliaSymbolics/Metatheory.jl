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
a match. **Note**: you have to escape types with `\$`!
```julia
Rule(:(a::\$Number * b::\$Number |> a*b))
```
"""
function Rule(e::Expr; mod::Module=@__MODULE__)
    e = rmlines(copy(e))
    mode = :undef
    mode = getfunsym(e)
    l, r = e.args[iscall(e) ? (2:3) : (1:2)]

    if mode ∈ raw_syms
        mode = :raw
        l = mod.eval(l, mod)
    elseif mode ∈ dynamic_syms # right hand execution, dynamic rules in egg
        mode = :dynamic
        l = interpolate_dollar(l, mod)
    elseif mode ∈ rewrite_syms # right side is quoted, symbolic replacement
        mode = :rewrite
        l = interpolate_dollar(l, mod)
    else
        error(`rule "$e" is not in valid form.\n`)
    end

    e.args[iscall(e) ? 2 : 1] = l
    return Rule(l, r, e, mode)
end

macro rule(e)
    Rule(e; mod=__module__)
end

# string representation of the rule
function Base.show(io::IO, x::Rule)
    println(io, "Rule(:(", x.expr, "))")
end
