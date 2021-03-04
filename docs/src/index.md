# Metatheory.jl

```@raw html
<p align="center">
<img width="400px" src="https://raw.githubusercontent.com/0x0f0f0f/Metatheory.jl/master/docs/src/assets/dragon.jpg"/>
</p>
```

**Metatheory.jl** is a general purpose metaprogramming and algebraic computation library for the Julia programming language, designed to take advantage of the powerful reflection capabilities to bridge the gap between symbolic mathematics, abstract interpretation, equational reasoning, optimization, composable compiler transforms, and advanced
homoiconic pattern matching features.

Read the [preprint on arXiv](https://arxiv.org/abs/2102.07888).

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
