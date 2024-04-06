# 3.0
- Updated TermInterface to 0.4.1

# 2.0
- No longer dispatch against types, but instead dispatch against objects.
- Faster E-Graph Analysis
- Better library macros 
- Updated TermInterface to 0.3.3
- New interface for e-graph extraction using `EGraphs.egraph_reconstruct_expression`
- Simplify E-Graph Analysis Interface. Use Symbols or functions for identifying Analyses. 
- Remove duplicates in E-Graph analyses data.

## 1.2
- Fixes when printing patterns
- Can pass custom `similarterm` to `SaturationParams` by using `SaturationParams.simterm`.

## 1.1
- EGraph pattern matcher can now match against both symbols and function objects
- Fixes for Symbolics.jl integration


## 1.0

Metatheory.jl + SymbolicUtils.jl = ❤️

- Metatheory.jl now supports the same syntax as [SymbolicUtils.jl](https://github.com/JuliaSymbolics/SymbolicUtils.jl/) for the rule definition DSL!
- The classical pattern matcher has been redesigned, and it is a port of [SymbolicUtils.jl](https://github.com/JuliaSymbolics/SymbolicUtils.jl/)'s pattern matcher. Now Metatheory.jl can be used in place of SU's rewriting backend.
- Performance improvements: caching of ground terms when doing e-matching in equality saturation.
- Dynamic Rules do not use RuntimeGeneratedFunctions when not needed.
- Removed `@metatheory_init`
- Rules now support type and function predicates as in SymbolicUtils.jl
- Redesigned the library
- Introduced `@timerewrite` to time the execution of classical rewriting systems.