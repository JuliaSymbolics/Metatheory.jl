
### IDE

It is recommended to use VSCode when programming in Julia. Its Julia extension
exclusively has shortcuts for evaluating Julia code, can display results inline
and has some support for working with system images, among others, which
typically make it better suited than other editors (unless you spend some effort
customizing another editor to your workflow). For autocompletions, linting and
navigation, it uses the Language Server Protocol (LSP) which you can reuse in
other text editors that support it.

#### Recommended VSCode extensions

- Julia: the official Julia extension. 
- GitLens: lets you see inline which
commit recently affected the selected line. It is excellent to know who was
working on a piece of code, such that you can easily ask for explanations or
help in case of trouble.

### Reduce latency with system images

We can put package dependencies into a system image (kind of like a snapshot of
a Julia session, abbreviated as sysimage) to speed up their loading.

### Logging

To turn on debug logging for a given module, set the environment variable
`JULIA_DEBUG` to the name of the module. For example, to enable debugging from
module Foo, just do

```bash
JULIA_DEBUG=Foo julia --project test/runtests.jl
```

Or from REPL
```julia
ENV["JULIA_DEBUG"] = Foo
```

## Collaboration

Once you have developed a piece of code and want to share it with the team, you
can create a merge request. If the changes are not final and will require
further work before considering a merge, then please mark the merge request as a
draft.

Merge requests marked as drafts may not be reviewed. If you seek a review from
someone, you should explicitly state it in the merge request and tag the person
in question.

When you are confident in your changes and want to consider a merge, you can
mark the merge request as ready. It will then be reviewed, and when review
comments are addressed, an automatic merge will be issued.

## Style

Code style is different from [[#Formatting]]. While the latter can be easily
assisted with by automatic tools, the former cannot.

### Comments

Comments and error messages should form proper sentences unless they are titles.

Get something done later, but only if someone looks at this code again. For
larger things make an issue.

```
# TODO: ...
```

Sometimes a piece of code is written in a certain way to work around an existing
issue in a dependency. If this code should be cleaned up after that issue is
fixed then the following line with link to issue should be added.

```
# ISSUE: https://
```

Probabilistic tests can sometimes fail in CI. If that is the case they should be marked with [`@test_skip`](https://docs.julialang.org/en/v1/stdlib/Test/#Test.@test_skip), which indicates that the test may intermittently fail (it will be reported in the test summary as `Broken`). This is equivalent to `@test (...) skip=true` but requires at least Julia v1.7. A comment before the relevant line is useful so that they can be debugged and made more reliable. 

```
# FLAKY
@test_skip some_probabilistic_test()
```

For packages that do not have to be used as libraries, it is sometimes
convenient to extend external methods on external types - this is referred to as
"type piracy" in Julia style guide. Generally it should be avoided, but for the
cases where it is very convenient it should be tagged.

```
# PIRACY
```

### Code

Generally follow the [Julia Style Guide](https://docs.julialang.org/en/v1/manual/style-guide/) with some caveats:
- [Avoid elaborate container types](https://docs.julialang.org/en/v1/manual/style-guide/#Avoid-elaborate-container-types): if explicitly typing a complex container helps with safety then you should do it. But, if a container type is not concrete (abstract type or unparametrized parametric type), nesting it inside another container probably won't do what you intend (Julia types are invariant). For example:
  ```julia
  # Don't
  const NestedContainer = AbstractDict{Symbol,Vector{Array}}
  Dict{Float64, AbstractDict{Symbol,NestedContainer}}
  
  # Do
  Dict{Float64, <:AbstractDict}
  Dict{Float64, Vector{Int}}

  const Bytes = Vector{UInt8}
  struct BytesCollections
    collections::Vector{Bytes}
  end
  AbstractDict{Symbol, BytesCollections}
  ```
- [Avoid type piracy](https://docs.julialang.org/en/v1/manual/style-guide/#Avoid-type-piracy): this is more important for libraries, but in a self-contained project this may be a nice feature.
- Prefer `Foo[]` and `Pair{Symbol,Foo}[]` over `Vector{Foo}()` and  `Vector{Pair{Symbol,Foo}}()` for better readability.
- Avoid explicit use of the `return` keyword if it is pointless, e.g. when a function has a unique point of return.

Otherwise follow this:

```julia
"Module definition first."
module ExampleModule

# `using` of external modules.
using Distributions: Normal
# `using` of symbols from internal modules, always explicitly name them.
using ..SomeNeighbourModule: nicefn

# `import` of symbols, usually to be extended, with the exception of those from `Base` (see below).
import StatsBase: mean

# ---------------------
# # First main section.

# Above begins a section of code which is readable with [Literate.jl](https://fredrikekre.github.io/Literate.jl/v2/fileformat/).

"Function docs as usual. Write proper sentences."
f(x) = x^2

# -----------------------
# ## Title of subsection.

"Some code in subsection."
g(x) = log(x)

# ----------------------
# # Second main section.

struct A
  id::Int64
end

"Keep constructors close to datastructure definitions."
A() = A(rand(1:10))

"""
Do not use explicit type parameters if not needed.

Use multi-line strings for longer docstrings.
"""
h(x::Vector{<:Real})::String = "Real vector."
h(x::Vector) = nothing
"""
Use output type annotations when the return type is not clear from context.
This facilitates readability by not requiring the reader to look for the lastly executed statement(s).
"""
function h(x)::Float64
  compute_something(x)
end
h(::Nothing) = 2

"Here the type parameter is used twice - it was needed."
i(x::Vector{T})::T where T<:Real = sum(x)

# Extend symbols defined in `Base` prepending the module's name.
Base.convert(::Type{Expr}, ::Type{Union{}}) = :(Union{})

end
```

Concerning unit testing, it is a good practice to use [SafeTestsets.j](https://github.com/YingboMa/SafeTestsets.jl), since it makes every single test script an independently runnable file. In turn, this implies that imports need to be manually added in each file. Moreover, we prefer to use explicit imports since that helps to keep tests targeted at what they should be testing. Hence, we suggest the following guidelines in test scripts (which should be included using `@safetestset`):

```julia
# load modules (eventually, also package itself)
using Test, MacroTools
# load specific names from external dependencies
using MeasureTheory: Dirac
# load specific names from MyPackage submodules (sorted alphabetically)
using MyPackage.SomeModule: Foo, bar, Baz, ⊕


@testset "Descriptive name" begin
 # ...
end
```

## Formatting

Use [JuliaFormatter.jl](https://github.com/domluna/JuliaFormatter.jl) to ensure that all code is formatted consistently. There should be a CI job that automatically checks for formatting. However, everyone is encouraged to use the formatter locally before pushing, see usage details below. 

Notable settings:
- Use two spaces for indentation: by default the Julia guide recommends four, but that tends to push code too much to the right.

### VS Code
If you are using VS code and the Julia Extension, you can also trigger the formatter via [various shortcuts](https://www.julia-vscode.org/docs/stable/userguide/formatter/).

