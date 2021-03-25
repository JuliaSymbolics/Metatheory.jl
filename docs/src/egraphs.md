# EGraphs and Equality Saturation


An EGraph is an efficient data structure for representing congruence relations.
EGraphs are data structures originating from theorem provers. Several projects have very recently 
repurposed EGraphs to implement state-of-the-art, rewrite-driven compiler optimizations and program synthesizers using a technique known as equality saturation.
Metatheory.jl provides a general purpose, customizable implementation of EGraphs and equality saturation, inspired from the [egg](https://egraphs-good.github.io/) library for Rust. You can read more about the design
of the EGraph data structure and equality saturation algorithm in the
[egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304).

## What can I do with EGraphs in Metatheory.jl?

Most importantly, the EGraph backend for Metatheory.jl allows
you to create an EGraph from a starting expression, to add more expressions to the EGraph with `addexpr!`, and then to effectively fill the EGraph with all possible equivalent expressions resulting from applying rewrite rules from a theory, by using the `saturate!` function. You can then easily
extract expressions with a cost function and an `ExtractionAnalysis`.

A killer feature of [egg](https://egraphs-good.github.io/) and Metatheory.jl
are **EGraph Analyses**. They allow you to annotate expressions and equivalence classes in an EGraph with values from a semilattice domain, and then to:
* Extract expressions from an EGraph basing from analysis data.
* Have conditional rules that are executed if some criteria is met on analysis data
* Have dynamic rules that compute the right hand side based on analysis data.


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

## The Metatheory Library

The `Metatheory.Library` module contains utility functions and macros for creating
rules and theories from commonly used algebraic structures and
properties.
```julia
using Metatheory.Library

comm_monoid = commutative_monoid(:(*), 1)
# alternatively
comm_monoid = @commutative_monoid (*) 1
```



## Equality Saturation

We can programmatically build and saturate an EGraph.
The function `saturate!` takes an `EGraph` and a theory, and executes
equality saturation. Returns a report
of the equality saturation process.
`saturate!` is configurable, customizable parameters include
a `timeout` on the number of iterations, a `eclasslimit` on the number of e-classes in the EGraph, a `stopwhen` functions that stops saturation when it evaluates to true.
```julia
G = EGraph(:((a * b) * (1 * (b + c))));
report = saturate!(G, t);
# access the saturated EGraph
report.egraph

# show some fancy stats
println(report);

```

With the EGraph equality saturation backend, Metatheory.jl can prove **simple** equalities very efficiently. The `@areequal` macro takes a theory and some
expressions and returns true iff the expressions are equal
according to the theory. The following example returns true.
```julia
@areequal t (x+y)*(a+b) ((a*(x+y))+b*(x+y)) ((x*(a+b))+y*(a+b))
```


### Configurable Parameters

[`saturate!`](@ref) can accept an additional parameter of type
[`SaturationParams`](@ref) to configure the equality saturation algorithm.
The documentation for the configurable parameters is available in the [`SaturationParams`](@ref) API docstring.

```julia
# create the saturation params
params = SaturationParams(timeout=10, eclasslimit=4000)
saturate!(egraph, theory, params)
```
