## 0.7

- The classical pattern matcher has been redesigned, and it is a port of
[SymbolicUtils.jl](https://github.com/JuliaSymbolics/SymbolicUtils.jl/)'s pattern matcher. Now Metatheory.jl can be used in place of SU's rewriting backend.
- Metatheory.jl now supports the same syntax as [SymbolicUtils.jl](https://github.com/JuliaSymbolics/SymbolicUtils.jl/) for the rule definition DSL.
- Performance improvements: caching of ground terms when doing e-matching in equality saturation.
- Dynamic Rules do not use RuntimeGeneratedFunctions when not needed.
- Removed `@metatheory_init`