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