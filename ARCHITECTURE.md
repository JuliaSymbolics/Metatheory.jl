# Code Structure

`src/`: Source Code for Metatheory.jl
- `TermInterface.jl`: Definition of the interface for using custom term types in Metatheory. Implementation for `Expr` and fallback.
- `rule.jl`: Definition of `Rule` type for rewrite rules. Utility functions and macros for handling rules. Contains definition of global dynamic rule function cache.
- `rgf.jl`: Utility functions for handling and generating Runtime Generated Functions 
- `EGraphs/`: Code for the e-graphs rewriting backend. See [egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304) for an high level overview.
  - `enode.jl`: Definition of `ENode` type, constructors
  - `eclass.jl`: Definition of `EClass` type. EClass unioning, metadata access
  - `egg.jl`: Defintion of EGraphs, adding, merging, rebuilding
  - `ematch.jl`: Pattern matching functions on egraphs
  - `abstractanalysis.jl`: Definition of `AbstractAnalysis` interface
  - `analysis.jl`: Core algorithms for analyzing egraphs.
  - `extraction.jl`: Core algorithms for `ExtractionAnalysis`, extracting terms from egraphs.
  - `saturation.jl`: Core algorithm for equality saturation, rewriting on e-graphs. Search, application and instantiation of matching results.
  - `saturation_params.jl`: Definition of `SaturationParams` type, parameters for equality saturation
  - `saturation_report.jl`: Definition of the type for displaying equality saturation execution reports.
  - `equality.jl`: utility functions and macros to check equality of terms in egraphs.
  - `Schedulers/`: Module containing definition of Schedulers for equality saturation. 
- `Classic/`: Classical deterministic rewriting backend using MatchCore.jl
  - `matchcore_compiler.jl`: Compiler from Metatheory rules to MatchCore pattern matching blocks, on top of RuntimeGeneratedFunctions.jl
  - `rewrite.jl`: Core rewriting algorithm based on fixpoint iteration of rewrite steps.
  - `match.jl`: Utility functions and macros for classical pattern matching with Metatheory.jl
- `Library/`: Utility functions and examples of ready-to-use theories.
  - `algebra.jl`: Functions for generating theories from common algebraic structures.  
- `Util/`: Module containing various utilities for metaprogramming, expression walking, quoted code cleaning, fixed point iterators.