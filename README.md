<p align="center">
<img width="400px" src="https://raw.githubusercontent.com/0x0f0f0f/Metatheory.jl/master/docs/src/assets/dragon.jpg"/>
</p>

# Metatheory.jl

[![Docs](https://img.shields.io/badge/docs-latest-blue.svg)](https://0x0f0f0f.github.io/Metatheory.jl/dev)
![CI](https://github.com/0x0f0f0f/Metatheory.jl/workflows/CI/badge.svg)
[![codecov](https://codecov.io/gh/0x0f0f0f/Metatheory.jl/branch/master/graph/badge.svg?token=EWNYPD7ASX)](https://codecov.io/gh/0x0f0f0f/Metatheory.jl)
[![arXiv](https://img.shields.io/badge/arXiv-2102.07888-b31b1b.svg)](https://arxiv.org/abs/2102.07888)
[![status](https://joss.theoj.org/papers/3266e8a08a75b9be2f194126a9c6f0e9/status.svg)](https://joss.theoj.org/papers/3266e8a08a75b9be2f194126a9c6f0e9)
[![Zulip](https://img.shields.io/badge/Chat-Zulip-blue)](https://julialang.zulipchat.com/#narrow/stream/277860-metatheory.2Ejl)

**Metatheory.jl** is a general purpose metaprogramming and algebraic computation library for the Julia programming language, designed to take advantage of the powerful reflection capabilities to bridge the gap between symbolic mathematics, abstract interpretation, equational reasoning, optimization, composable compiler transforms, and advanced
homoiconic pattern matching features. The core feature of Metatheory.jl is *e-graph rewriting*, a fresh approach to term rewriting achieved through an equality saturation algorithm.

Intuitively, Metatheory.jl transforms Julia expressions
in other Julia expressions and can achieve such at both compile and run time. This allows Metatheory.jl users to perform customized and composable compiler optimization specifically tailored to single, arbitrary Julia packages.
Our library provides a simple, algebraically composable interface to help scientists in implementing and reasoning about semantics and all kinds of formal systems, by defining concise rewriting rules in pure, syntactically valid Julia on a high level of abstraction. Our implementation of equality saturation on e-graphs is based on the excellent, state-of-the-art technique implemented in the [egg](https://egraphs-good.github.io/) library, reimplemented in pure Julia.

## Recommended Readings - Selected Publications

- The [Metatheory.jl introductory paper](https://joss.theoj.org/papers/10.21105/joss.03078#) gives a brief high level overview on the library and its functionalities.
- The Julia Manual [metaprogramming section](https://docs.julialang.org/en/v1/manual/metaprogramming/) is fundamental to understand what homoiconic expression manipulation is and how it happens in Julia.
- An [introductory blog post on SIGPLAN](https://blog.sigplan.org/2021/04/06/equality-saturation-with-egg/) about `egg` and e-graphs rewriting.
- [egg: Fast and Extensible Equality Saturation](https://dl.acm.org/doi/pdf/10.1145/3434304) contains the definition of *E-Graphs* on which Metatheory.jl's equality saturation rewriting backend is based. This is a strongly recommended reading.

## Contributing

If you'd like to give us a hand and contribute to this repository you can:
- Find a high level description of the project architecture in [ARCHITECTURE.md](https://github.com/0x0f0f0f/Metatheory.jl/blob/master/ARCHITECTURE.md)
- Read the contribution guidelines in [CONTRIBUTING.md](https://github.com/0x0f0f0f/Metatheory.jl/blob/master/CONTRIBUTING.md)

If you enjoy Metatheory.jl and would like to help, please also consider a [tiny donation](https://github.com/sponsors/0x0f0f0f/). 
It can help me a lot in actively developing this project.

## Please note that Metatheory.jl is in an experimental alpha stage and many things are going to change 

## Installation

You can install the stable version:
```julia
julia> using Pkg; Pkg.add("Metatheory")
```

Or you can install the developer version (recommended by now for latest bugfixes)
```julia
julia> using Pkg; Pkg.add(url="https://github.com/0x0f0f0f/Metatheory.jl")
```
## Usage

TODO update usage

## Documentation

Narrative and API documentation for Metatheory.jl is available [here](https://0x0f0f0f.github.io/Metatheory.jl/dev)

## Citing

If you use Metatheory.jl in your research, please [cite](https://github.com/0x0f0f0f/Metatheory.jl/blob/master/CITATION.bib) our works.

--- 

<p align="center">
<a href="https://planting.space"> 
    <img width="300px" src="https://raw.githubusercontent.com/0x0f0f0f/Metatheory.jl/master/.github/plantingspace.png"/>
</a>
</p>
