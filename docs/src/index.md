# Metatheory.jl 1.0

```@raw html
<p align="center">
<img width="400px" src="https://raw.githubusercontent.com/juliasymbolics/Metatheory.jl/master/docs/src/assets/dragon.jpg"/>
</p>
```

[![Docs](https://img.shields.io/badge/docs-latest-blue.svg)](https://juliasymbolics.github.io/Metatheory.jl/dev/)
[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliasymbolics.github.io/Metatheory.jl/stable/)
![CI](https://github.com/juliasymbolics/Metatheory.jl/workflows/CI/badge.svg)
[![codecov](https://codecov.io/gh/juliasymbolics/Metatheory.jl/branch/master/graph/badge.svg?token=EWNYPD7ASX)](https://codecov.io/gh/juliasymbolics/Metatheory.jl)
[![arXiv](https://img.shields.io/badge/arXiv-2102.07888-b31b1b.svg)](https://arxiv.org/abs/2102.07888)
[![status](https://joss.theoj.org/papers/3266e8a08a75b9be2f194126a9c6f0e9/status.svg)](https://joss.theoj.org/papers/3266e8a08a75b9be2f194126a9c6f0e9)
[![Zulip](https://img.shields.io/badge/Chat-Zulip-blue)](https://julialang.zulipchat.com/#narrow/stream/277860-metatheory.2Ejl)

**Metatheory.jl** is a general purpose term rewriting, metaprogramming and algebraic computation library for the Julia programming language, designed to take advantage of the powerful reflection capabilities to bridge the gap between symbolic mathematics, abstract interpretation, equational reasoning, optimization, composable compiler transforms, and advanced
homoiconic pattern matching features. The core features of Metatheory.jl are a powerful rewrite rule definition language, a vast library of functional combinators for classical term rewriting and an *e-graph rewriting*, a fresh approach to term rewriting achieved through an equality saturation algorithm. Metatheory.jl can manipulate any kind of
Julia symbolic expression type, as long as it satisfies the [TermInterface.jl](https://github.com/JuliaSymbolics/TermInterface.jl).

Metatheory.jl provides:
- An eDSL (domain specific language) to define different kinds of symbolic rewrite rules.
- A classical rewriting backend, derived from the [SymbolicUtils.jl](https://github.com/JuliaSymbolics/SymbolicUtils.jl) pattern matcher, supporting associative-commutative rules. It is based on the pattern matcher in the [SICM book](https://mitpress.mit.edu/sites/default/files/titles/content/sicm_edition_2/book.html).
- A flexible library of rewriter combinators.
- An e-graph rewriting (equality saturation) backend and pattern matcher, based on the [egg](https://egraphs-good.github.io/) library, supporting backtracking and non-deterministic term rewriting by using a data structure called *e-graph*, efficiently incorporating the notion of equivalence in order to reduce the amount of user effort required to achieve optimization tasks and equational reasoning.
- `@capture` macro for flexible metaprogramming.

Intuitively, Metatheory.jl transforms Julia expressions
in other Julia expressions and can achieve such at both compile and run time. This allows Metatheory.jl users to perform customized and composable compiler optimizations specifically tailored to single, arbitrary Julia packages.
Our library provides a simple, algebraically composable interface to help scientists in implementing and reasoning about semantics and all kinds of formal systems, by defining concise rewriting rules in pure, syntactically valid Julia on a high level of abstraction. Our implementation of equality saturation on e-graphs is based on the excellent, state-of-the-art technique implemented in the [egg](https://egraphs-good.github.io/) library, reimplemented in pure Julia.

## 1.0 is out!

The first stable version of Metatheory.jl is out! The goal of this release is to unify the symbolic manipulation ecosystem of Julia packages. Many features have been ported from SymbolicUtils.jl. Now, Metatheory.jl can be used in place of SymbolicUtils.jl when you have no need of manipulating mathematical expressions. SymbolicUtils.jl can now completely leverage on the generic stack of rewriting features provided by Metatheory.jl, highly decoupled from the symbolic term representation thanks to [TermInterface.jl](https://github.com/JuliaSymbolics/TermInterface.jl). Read more in [NEWS.md](https://github.com/JuliaSymbolics/Metatheory.jl/blob/master/NEWS.md).

## Recommended Readings - Selected Publications

- The [Metatheory.jl manual](https://juliasymbolics.github.io/Metatheory.jl/stable/) 
- The [Metatheory.jl introductory paper](https://joss.theoj.org/papers/10.21105/joss.03078#) gives a brief high level overview on the library and its functionalities.
- The Julia Manual [metaprogramming section](https://docs.julialang.org/en/v1/manual/metaprogramming/) is fundamental to understand what homoiconic expression manipulation is and how it happens in Julia.
- An [introductory blog post on SIGPLAN](https://blog.sigplan.org/2021/04/06/equality-saturation-with-egg/) about `egg` and e-graphs rewriting.
- [egg: Fast and Extensible Equality Saturation](https://dl.acm.org/doi/pdf/10.1145/3434304) contains the definition of *E-Graphs* on which Metatheory.jl's equality saturation rewriting backend is based. This is a strongly recommended reading.
- [High-performance symbolic-numerics via multiple dispatch](https://arxiv.org/abs/2105.03949): a paper about how we used Metatheory.jl to optimize code generation in [Symbolics.jl](https://github.com/JuliaSymbolics/Symbolics.jl)

## Contributing

If you'd like to give us a hand and contribute to this repository you can:
- Find a high level description of the project architecture in [ARCHITECTURE.md](https://github.com/juliasymbolics/Metatheory.jl/blob/master/ARCHITECTURE.md)
- Read the contribution guidelines in [CONTRIBUTING.md](https://github.com/juliasymbolics/Metatheory.jl/blob/master/CONTRIBUTING.md)

If you enjoyed Metatheory.jl and would like to help, please also consider a [tiny donation 💕](https://github.com/sponsors/0x0f0f0f/)!

## Installation

You can install the stable version:
```julia
julia> using Pkg; Pkg.add("Metatheory")
```

Or you can install the developer version (recommended by now for latest bugfixes)
```julia
julia> using Pkg; Pkg.add(url="https://github.com/JuliaSymbolics/Metatheory.jl")
```

## Documentation

Extensive Metatheory.jl is available [here](https://juliasymbolics.github.io/Metatheory.jl/dev)

## Citing

If you use Metatheory.jl in your research, please [cite](https://github.com/juliasymbolics/Metatheory.jl/blob/master/CITATION.bib) our works.

--- 

<p align="center">
<a href="https://planting.space"> 
    <img width="300px" src="https://raw.githubusercontent.com/juliasymbolics/Metatheory.jl/master/.github/plantingspace.png"/>
</a>
</p>
