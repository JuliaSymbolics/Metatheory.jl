# Metatheory.jl

```@raw html
<p align="center">
<img width="400px" src="https://raw.githubusercontent.com/0x0f0f0f/Metatheory.jl/master/docs/src/assets/dragon.jpg"/>
</p>
```

**Metatheory.jl** is a general purpose metaprogramming and algebraic computation library for the Julia programming language, designed to take advantage of the powerful reflection capabilities to bridge the gap between symbolic mathematics, abstract interpretation, equational reasoning, optimization, composable compiler transforms, and advanced
homoiconic pattern matching features. The core feature of Metatheory.jl is *e-graph rewriting*, a fresh approach to term rewriting achieved through an equality saturation algorithm.

Intuitively, Metatheory.jl transforms Julia expressions
in other Julia expressions and can achieve such at both compile and run time. This allows Metatheory.jl users to perform customized and composable compiler optimization specifically tailored to single, arbitrary Julia packages.
Our library provides a simple, algebraically composable interface to help scientists in implementing and reasoning about semantics and all kinds of formal systems, by defining concise rewriting rules in pure, syntactically valid Julia on a high level of abstraction. Our implementation of equality saturation on e-graphs is based on the excellent, state-of-the-art technique implemented in the [egg](https://egraphs-good.github.io/) library, reimplemented in pure Julia.



## Recommended Readings - Selected Publications

- The [Metatheory.jl introductory paper](https://joss.theoj.org/papers/10.21105/joss.03078#) gives a brief high level overview on the library and its functionalities.
- The Julia Manual [metaprogramming section](https://docs.julialang.org/en/v1/manual/metaprogramming/) is fundamental to understand what homoiconic expression manipulation is and how it happens in Julia.
- [egg: Fast and Extensible Equality Saturation](https://dl.acm.org/doi/pdf/10.1145/3434304) contains the original definition of *E-Graphs* on which Metatheory.jl's equality saturation e-graph rewriting backend is based. This is a strongly recommended reading.

## Installation

You can install the stable version:
```julia
julia> using Pkg; Pkg.add("Metatheory")
```

Or you can install the development version (recommended by now for latest bugfixes)
```julia
julia> using Pkg; Pkg.add(url="https://github.com/0x0f0f0f/Metatheory.jl")
```

## Usage

Since Metatheory.jl relies on [RuntimeGeneratedFunctions.jl](https://github.com/SciML/RuntimeGeneratedFunctions.jl/), you have to call `@metatheory_init` in the module where you are going to use Metatheory.

```julia
using Metatheory
using Metatheory.EGraphs

@metatheory_init ()
```

## Citing

If you use Metatheory.jl in your research, please [cite](https://github.com/0x0f0f0f/Metatheory.jl/blob/master/CITATION.bib) our works.
