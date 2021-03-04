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

You can install the stable version:
```julia
julia> using Pkg; Pkg.add("Metatheory")
```

Or you can install the developer version (recommended by now for latest bugfixes)
```julia
julia> using Pkg; Pkg.add(url="https://github.com/0x0f0f0f/Metatheory.jl")
```
## Usage

Since Metatheory.jl relies on [RuntimeGeneratedFunctions.jl](https://github.com/SciML/RuntimeGeneratedFunctions.jl/), you have to call `@metatheory_init` in the module where you are going to use Metatheory.

```julia
using Metatheory
using Metatheory.EGraphs

@metatheory_init
```

## Documentation

Narrative and API documentation for Metatheory.jl is available [here](https://0x0f0f0f.github.io/Metatheory.jl/dev)

## Please note that Metatheory.jl is in an experimental stage and THINGS ARE GOING TO CHANGE, A LOT
