# Code Structure in `src/`

## Patterns Module

This module provides the type hierarchy required to build patterns, the
left hand side of rules.
- `errors.jl`: error types
- `pattern.jl`: pattern types and constructors

## Rule Module
This module contains core definition for rewrite rules and classical
rewriting pattern matcher

- `patterns.jl`: Pattern type definitions for various pattern matching backends.
- `patterns_syntax.jl`: Julia expressions to Patterns and pretty-printing patterns.
- `acrule.jl`: Associative-Commutative rules. 
- `rewriterule.jl`: Symbolic-substitution rules.
- `dynamicrule.jl`: RHS-evaluating rules
- `equalityrule.jl`: bidirectional symbolic rules for e-graph rewriting
- `unequalrule.jl`: inequality rules to eagerly halt eqsat.
- `matchers.jl`: Classical rewriting pattern matcher.
- `utils.jl`: Various utilities for pattern matching

# NewSyntax Module
Contains the frontend to Rules and Patterns (`@rule` macro and `Pattern` function), using the new Metatheory.jl syntax.

# SUSyntax Module
Contains the frontend to Rules and Patterns (`@rule` macro and `Pattern` function), using the SymbolicUtils.jl syntax.

# EGraphs Module 
Contains code for the e-graphs rewriting backend. See [egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304) for an high level overview.

- `enode.jl`: Definition of `ENode` type, constructors
- `eclass.jl`: Definition of `EClass` type. EClass unioning, metadata access
- `egg.jl`: Defintion of EGraphs, adding, merging, rebuilding
- `ematch.jl`: Pattern matching functions on egraphs
- `abstractanalysis.jl`: Definition of `AbstractAnalysis` interface
- `analysis.jl`: Core algorithms for analyzing egraphs.
- `extraction.jl`: Core algorithms for `ExtractionAnalysis`, extracting terms from egraphs.
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
