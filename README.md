<p align="center">
<img width="400px" src="https://raw.githubusercontent.com/0x0f0f0f/Metatheory.jl/master/docs/src/assets/dragon.jpg"/>
</p>

# Metatheory.jl

[![Docs](https://img.shields.io/badge/docs-latest-blue.svg)](https://0x0f0f0f.github.io/Metatheory.jl/dev)
![CI](https://github.com/0x0f0f0f/Metatheory.jl/workflows/CI/badge.svg)
[![codecov](https://codecov.io/gh/0x0f0f0f/Metatheory.jl/branch/master/graph/badge.svg?token=EWNYPD7ASX)](https://codecov.io/gh/0x0f0f0f/Metatheory.jl)
[![arXiv](https://img.shields.io/badge/arXiv-2102.07888-b31b1b.svg)](https://arxiv.org/abs/2102.07888)
[![Zulip](https://img.shields.io/badge/Chat-Zulip-blue)](https://julialang.zulipchat.com/#narrow/stream/277860-metatheory.2Ejl)

**Metatheory.jl** is a general purpose metaprogramming and algebraic computation library for the Julia programming language, designed to take advantage of the powerful reflection capabilities to bridge the gap between symbolic mathematics, abstract interpretation, equational reasoning, optimization, composable compiler transforms, and advanced
homoiconic pattern matching features.

Intuitively, Metatheory.jl transforms Julia expressions
in other Julia expressions and can achieve such at both compile and run time. This allows Metatheory.jl users to perform customized and composable compiler optimization specifically tailored to single, arbitrary Julia packages.
Our library provides a simple, algebraically composable interface to help scientists in implementing and reasoning about semantics and all kinds of formal systems, by defining concise rewriting rules in pure, syntactically valid Julia on a high level of abstraction. Our implementation of equality saturation on e-graphs is based on the excellent, state-of-the-art technique implemented in the [egg](https://egraphs-good.github.io/) library, reimplemented in pure Julia.

## Citing

If you use Metatheory.jl in your research, please [cite](https://github.com/0x0f0f0f/Metatheory.jl/blob/master/CITATION.bib) our works.

```
@misc{cheli2021metatheoryjl,
      title={Metatheory.jl: Fast and Elegant Algebraic Computation in Julia with Extensible Equality Saturation},
      author={Alessandro Cheli},
      year={2021},
      eprint={2102.07888},
      archivePrefix={arXiv},
      primaryClass={cs.PL}
}
```

## Installation

```julia
julia> using Pkg; Pkg.add(url="https://github.com/0x0f0f0f/Metatheory.jl")
```

## Please note that Metatheory.jl is in an experimental stage and THINGS ARE GOING TO CHANGE, A LOT

## Examples

Here are some of examples of the basic workflow of using Metatheory.jl. Theories are composable and reusable!
Since Metatheory.jl relies on [RuntimeGeneratedFunctions.jl](https://github.com/SciML/RuntimeGeneratedFunctions.jl/), you have to call `@metatheory_init` in the module where you are going to use Metatheory.

```julia
using Metatheory
using Metatheory.EGraphs

@metatheory_init
```

### Basic Symbolic Mathematics

#### Theories and Algebraic Structures
The e-graphs backend can directly handle associativity,
commutativity and distributivity, rules that are
otherwise known of causing loops in symbolic computations.

```julia
comm_monoid = @theory begin
    a * b => b * a
    a * 1 => a
    a * (b * c) => (a * b) * c
end
```

#### The Metatheory Library


The `Metatheory.Library` module contains utility functions and macros for creating
rules and theories from commonly used algebraic structures and
properties. This is equivalent to the previous theory definition.
```julia
using Metatheory.Library

comm_monoid = commutative_monoid(:(*), 1)
# alternatively
comm_monoid = @commutative_monoid (*) 1
```

#### Theories are Collections and Composable

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

#### EGraphs

An EGraph is an efficient data structure for representing congruence relations.
Over the past decade, several projects have repurposed EGraphs to implement state-of-the-art, rewrite-driven compiler optimizations and program synthesizers using a technique known as equality saturation.
Metatheory.jl provides a general purpose, customizable implementation of EGraphs and equality saturation, inspired from the [egg](https://egraphs-good.github.io/) library for Rust. You can read more about the design
of the EGraph data structure and equality saturation algorithm in the
[egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304).

#### What can I do with EGraphs in Metatheory.jl?

Most importantly, the EGraph backend for Metatheory.jl allows
you to create an EGraph from a starting expression, to add more expressions to the EGraph with `addexpr!`, and then to effectively fill the EGraph with all possible equivalent expressions resulting from applying rewrite rules from a theory, by using the `saturate!` function. You can then easily
extract expressions with a cost function and an `ExtractionAnalysis`.

A killer feature of [egg](https://egraphs-good.github.io/) and Metatheory.jl
are **EGraph Analyses**. They allow you to annotate expressions and equivalence classes in an EGraph with values from a semilattice domain, and then to:
* Extract expressions from an EGraph basing from analysis data.
* Have conditional rules that are executed if some criteria is met on analysis data
* Have dynamic rules that compute the right hand side based on analysis data.

#### Equality Saturation

We can programmatically build and saturate an EGraph.
The function `saturate!` takes an `EGraph` and a theory, and executes
equality saturation. `saturate!` returns two values. The first returned value is boolean
`saturate!` is configurable, customizable parameters include
a `timeout` on the number of iterations, a `sizeout` on the number of e-classes in the EGraph, a `stopwhen` functions that stops saturation when it evaluates to true.
```julia
G = EGraph(:((a * b) * (1 * (b + c))))
saturated, G = saturate!(G, t)
```

With the EGraph equality saturation backend, Metatheory.jl can prove simple equalities very efficiently. The `@areequal` macro takes a theory and some
expressions and returns true iff the expressions are equal
according to the theory. The following example returns true.
```julia
@areequal t (x+y)*(a+b) ((a*(x+y))+b*(x+y)) ((x*(a+b))+y*(a+b))
```

#### Type Assertions and Dynamic Rules

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

Let's see a more complex example: extracting the
smallest equivalent expression, from a
trivial mathematics theory

```julia
distrib = @theory begin
	a * (b + c) => (a * b) + (a * c)
	(a * b) + (a * c) => a * (b + c)
end
powers = @theory begin
	a * a => a^2
	a => a^1
	a^n * a^m => a^(n+m)
end
logids = @theory begin
	log(a^n) => n * log(a)
	log(x * y) => log(x) * log(y)
	log(1) => 0
	log(:e) => 1
	:e^(log(x)) => x
end
fold_add = @theory begin
	a::Number + b::Number |> a + b
end
t = comm_monoid ∪ comm_group ∪ distrib ∪ powers ∪ logids ∪ fold_mul ∪ fold_add
```


#### Extracting from an E-Graph

Extraction can be formulated as an [EGraph analysis](https://dl.acm.org/doi/pdf/10.1145/3434304),
or after saturation. A cost function can be provided.
Metatheory.jl already provides some simple cost functions,
such as `astsize`, which expresses preference for the smallest expressions.

```julia
G = EGraph(:((log(e) * log(e)) * (log(a^3 * a^2))))
saturate!(G, t)
extractor = addanalysis!(G, ExtractionAnalysis, astsize)
ex = extract!(G, extractor)
ex == :(log(a) * 5)
```

### Classical Rewriting

There are some use cases where EGraphs and equality saturation are not
required. The **classical rewriting backend** is suited for **simple tasks**
when
computing the whole equivalence class is overkill. Metatheory.jl is meant for
composability: you can always compose and interleave rewriting steps that use
the classical rewriting backend or the more advanced EGraph backend.
For example, let's simplify an expression in the `comm_monoid` theory we
defined earlier, by using the EGraph backend. After simplification,
we may want to move all the `σ` symbols to the right of multiplications,
we can do this simple task with a *classical rewriting* step, by using
the `rewrite` function.

##### Step 1: Simplification with EGraphs
```julia
start_expr = :( (a * (1 * (2σ)) * (b * σ + (c * 1)) ) )
g = EGraph(start_expr);
extractor = addanalysis!(g, ExtractionAnalysis, astsize)
saturate!(g, comm_monoid);
simplified = extract!(g, extractor)
```

`simplified` will be `:(a * (σ * 2) * (σ * b + c))`

##### Step 2: Moving σ to the right
```julia
moveright = @theory begin
	:σ * a 				=> a*:σ
	(a * :σ) * b 	=> (a * b) * :σ
	(:σ * a) * b 	=> (a * b) * :σ
end

simplified = rewrite(simplified, moveright)
```

`simplified` is now `:((a * (2 * :σ)) * (b * :σ + c))`

### A Tiny Imperative Programming Language Interpreter

This example **does not** use the e-graphs backend. A recursive
algorithm is sufficient for interpreting expressions!
Note how we are representing semantics for a different programming language
by reusing the Julia AST data structure, and therefore efficiently reusing
the Julia parser for our new toy language.

See this [test file](https://github.com/0x0f0f0f/Metatheory.jl/blob/master/test/test_while_interpreter.jl).
