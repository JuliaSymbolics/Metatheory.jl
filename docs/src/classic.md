# Classical Rewriting

```@meta
CurrentModule = Metatheory
DocTestSetup  = quote
    using Metatheory
    using Metatheory.EGraphs
end
```

There are some use cases where EGraphs and equality saturation are not
required. The **classical rewriting backend** is suited for **simple tasks**
when computing the whole equivalence class is overkill.

The classical rewriting backend can be accessed with
the [`rewrite`](@ref) function, which
uses a recursive fixed point iteration algorithm to
rewrite a source expression. The expression can be traversed with a
**depth first** (inner left expression) evaluation order, or with a
**breadth first** (outer left expression) evaluation order. You can
configure the evaluation order by passing the keyword argument
`order=:inner` (default) or `order=:outer` to the `rewrite` function.

**Note**: With the classical [`rewrite`](@ref) algorithm, rules are matched in order and
applied deterministically:
every iteration, only the first rule that matches is applied.
This means that when using the **classical rewriting backend**, the **ordering
of rules in a theory matters!**. If some rules produce a loop, which is common
for regular algebraic rules such as *commutativity, distributivity and associativity*,
the other following rules in the theory *will never be applied*.

The classical `rewrite`
algorithm is suitable for:
- Simple Pattern Matching Tasks
- Interpretation of Code (e.g. interpretation of an eDSL)
- Non-Optimizing Compiler Steps and Transformations (e.g. Your eDSL --> Julia)
- Simple Deterministic Manipulation Tasks (e.g. cleaning expressions)

For algebraic, mathematics oriented rewriting, please
use the [`EGraph`](@ref) backend.

Rewriting loops are detected by keeping an history of hashes of the
rewritten expression. When a loop is detected, rewriting stops immediately
and returns the current expression.

Metatheory.jl is meant for
composability: you can always compose and interleave rewriting steps that use
the classical rewriting backend or the more advanced EGraph backend.

## Example

Let's simplify an expression in the `comm_monoid` theory
by using the EGraph backend. After simplification,
we may want to move all the `σ` symbols to the right of multiplications,
we can do this simple task with a *classical rewriting* step, by using
the `rewrite` function.

##### Step 1: Simplification with EGraphs

```@example classic
using Metatheory
using Metatheory.EGraphs
using Metatheory.Classic
using Metatheory.Library

@metatheory_init

comm_monoid = commutative_monoid(:(*), 1);
start_expr = :( (a * (1 * (2σ)) * (b * σ + (c * 1)) ) );
g = EGraph(start_expr);
saturate!(g, comm_monoid);
simplified = extract!(g, astsize)
```

##### Step 2: Moving σ to the right
```@example classic
moveright = @theory begin
	:σ * a 			=> a*:σ
	(a * :σ) * b 	=> (a * b) * :σ
	(:σ * a) * b 	=> (a * b) * :σ
end;

simplified = rewrite(simplified, moveright)
```

#### Assignment to variables during rewriting.

Using the *classical rewriting* backend, you may want
to assign a value to an externally defined variable.
Because of the nature of modules and the [`RuntimeGeneratedFunction`](https://github.com/SciML/RuntimeGeneratedFunctions.jl)
compilation pipeline, it is not possible to assign
values to variables in other modules.
You can achieve such behaviour by using Julia `References` [(docs)](https://docs.julialang.org/en/v1/base/c/#Core.Ref),
which behave similarly to pointers in other languages such as C or OCaml.

**Note**: due to nondeterminism, it is unrecommended to assign values to
`Ref`s when using the **EGraph** backend!

```@example classic
safe_var = 0
ref_var = Ref{Real}(0)

reft = @theory begin
	:safe |> (safe_var = π)
	:ref |> (ref_var[] = π)
end

rewrite(:(safe), reft; order=:inner, m=@__MODULE__)
rewrite(:(ref), reft; order=:inner, m=@__MODULE__)

(safe_var, ref_var[])
```

### A Tiny Imperative Programming Language Interpreter

Here is an example showing interpretation of a very tiny, turing complete
subset of the Julia programming language. To achieve turing completeness
in an imperative paradigm language, just integer+boolean arithmetic and
`if` and `while` statements are needed.
Since a recursive algorithm is sufficient for interpreting those expressions, this
example **does not** use the e-graphs backend!
Note how we are representing semantics for a different programming language
by reusing the Julia AST data structure, and therefore efficiently reusing
the Julia parser for our new toy language.

See this [test file](https://github.com/0x0f0f0f/Metatheory.jl/blob/master/test/test_while_interpreter.jl).

## API Docs

```@meta
CurrentModule = Metatheory
```

```@autodocs
Modules = [Metatheory.Classic]
```
