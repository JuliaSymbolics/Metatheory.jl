# Code Structure in `src/`

## Patterns Module

The `Patterns.jl` file contains type definitions for pattern matching building blocks 
called `AbstractPat`s, shared between pattern matching backends.
This module provides the type hierarchy required to build patterns, the
left hand side of rules.

## Rules 

- `Rules.jl`: definitions for rule types used in various rewriting backends.
- `matchers.jl`: Classical rewriting pattern matcher.

# `Syntax.jl`
Contains the frontend to Rules and Patterns (`@rule` macro and `Pattern` function), using the compatible SymbolicUtils.jl syntax.

# EGraphs Module 
Contains code for the e-graphs rewriting backend. See [egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304) for an high level overview.

- `egraph.jl`: Definition of `ENode`, `EClass` and `EGraph` types, EClass unioning, metadata access, definition of EGraphs, adding, merging, rebuilding.
- `analysis.jl`: Core algorithms for analyzing egraphs and extracting terms from egraphs.
- `saturation.jl`: Core algorithm for equality saturation, rewriting on e-graphs, e-graphs search.  Search phase of equality saturation. Uses multiple-dispatch on rules, Write phase of equality saturation. Application and instantiation of `Patterns` from matching/search results. Definition of `SaturationParams` type, parameters for equality saturation, Definition of equality saturation execution reports. Utility functions and macros to check equality of terms in egraphs.
- `Schedulers.jl`: Module containing definition of Schedulers for equality saturation. 


## `Library.jl`
Contains utility functions and examples of ready-to-use theories of rules. Macros that generate single rules corresponding to common algebraic properties and macros for generating theories from common algebraic structures.  
