# Code Structure in `src/`

## Patterns Module

The `Patterns.jl` file contains type definitions for pattern matching building blocks 
called `Pattern`s, shared between pattern matching backends.
This module provides the type hierarchy required to build patterns, the
left hand side of rules.

## Rules 

The `Rules` folder contains 
- `rules.jl`: definitions for rule types used in various rewriting backends.
- `matchers.jl`: Classical rewriting pattern matcher.

# `NewSyntax.jl`
Contains the frontend to Rules and Patterns (`@rule` macro and `Pattern` function), using the new Metatheory.jl syntax.

# `SUSyntax.jl`
Contains the frontend to Rules and Patterns (`@rule` macro and `Pattern` function), using the SymbolicUtils.jl syntax.

# EGraphs Module 
Contains code for the e-graphs rewriting backend. See [egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304) for an high level overview.

- `egraphs.jl`: Definition of `ENode`, `EClass` and `EGraph` types, EClass unioning, metadata access, defintion of EGraphs, adding, merging, rebuilding.
- `ematch.jl`: Pattern matching functions on egraphs
- `analysis.jl`: Core algorithms for analyzing egraphs and extracting terms from egraphs.
- `equality.jl`: utility functions and macros to check equality of terms in egraphs.
- `Schedulers/`: Module containing definition of Schedulers for equality saturation. 


## Saturation 
Inside of `EGraphs/saturation`

- `saturation.jl`: Core algorithm for equality saturation, rewriting on e-graphs. 
- `search.jl`: Search phase of equality saturation. Uses multiple-dispatch on `Rule`s
- `apply.jl`: Write phase of equality saturation. Application and instantiation of `Patterns` from matching/search results.
- `params.jl`: Definition of `SaturationParams` type, parameters for equality saturation
- `report.jl`: Definition of the type for displaying equality saturation execution reports.


## Library Module
Contains utility functions and examples of ready-to-use theories of rules.

- `rules.jl`: Macros that generate single rules corresponding to common algebraic properties
- `algebra.jl`: Macros for generating theories from common algebraic structures.  
