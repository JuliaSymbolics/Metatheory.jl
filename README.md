<p align="center">
<img width="400px" src="https://raw.githubusercontent.com/juliasymbolics/Metatheory.jl/master/docs/src/assets/dragon.jpg"/>
</p>

# Metatheory.jl

[![Docs](https://img.shields.io/badge/docs-latest-blue.svg)](https://juliasymbolics.github.io/Metatheory.jl/dev/)
[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliasymbolics.github.io/Metatheory.jl/stable/)
![CI](https://github.com/juliasymbolics/Metatheory.jl/workflows/CI/badge.svg)
[![codecov](https://codecov.io/gh/juliasymbolics/Metatheory.jl/branch/master/graph/badge.svg?token=EWNYPD7ASX)](https://codecov.io/gh/juliasymbolics/Metatheory.jl)
[![arXiv](https://img.shields.io/badge/arXiv-2102.07888-b31b1b.svg)](https://arxiv.org/abs/2102.07888)
[![status](https://joss.theoj.org/papers/3266e8a08a75b9be2f194126a9c6f0e9/status.svg)](https://joss.theoj.org/papers/3266e8a08a75b9be2f194126a9c6f0e9)
[![Zulip](https://img.shields.io/badge/Chat-Zulip-blue)](https://julialang.zulipchat.com/#narrow/stream/277860-metatheory.2Ejl)

**Metatheory.jl** is a general purpose term rewriting, metaprogramming and
algebraic computation library for the Julia programming language, designed to
take advantage of the powerful reflection capabilities to bridge the gap between
symbolic mathematics, abstract interpretation, equational reasoning,
optimization, composable compiler transforms, and advanced homoiconic pattern
matching features. The core features of Metatheory.jl are a powerful rewrite
rule definition language, a vast library of functional combinators for classical
term rewriting and an *[e-graph](https://en.wikipedia.org/wiki/E-graph)
rewriting*, a fresh approach to term rewriting achieved through an equality
saturation algorithm. Metatheory.jl can manipulate any kind of Julia symbolic
expression type, ~~as long as it satisfies the [TermInterface.jl](https://github.com/JuliaSymbolics/TermInterface.jl)~~.

### NOTE: TermInterface.jl has been temporarily deprecated. Its functionality has moved to module [Metatheory.TermInterface](https://github.com/JuliaSymbolics/Metatheory.jl/blob/master/src/TermInterface.jl) until consensus for a shared symbolic term interface is reached by the community.



Metatheory.jl provides:
- An eDSL (embedded domain specific language) to define different kinds of symbolic rewrite rules.
- A classical rewriting backend, derived from the [SymbolicUtils.jl](https://github.com/JuliaSymbolics/SymbolicUtils.jl) pattern matcher, supporting associative-commutative rules. It is based on the pattern matcher in the [SICM book](https://mitpress.mit.edu/sites/default/files/titles/content/sicm_edition_2/book.html).
- A flexible library of rewriter combinators.
- An [e-graph](https://en.wikipedia.org/wiki/E-graph) rewriting (equality saturation) engine, based on the [egg](https://egraphs-good.github.io/) library, supporting a backtracking  pattern matcher and non-deterministic term rewriting by using a data structure called [e-graph](https://en.wikipedia.org/wiki/E-graph), efficiently incorporating the notion of equivalence in order to reduce the amount of user effort required to achieve optimization tasks and equational reasoning.
- `@capture` macro for flexible metaprogramming.

Intuitively, Metatheory.jl transforms Julia expressions
in other Julia expressions at both compile and run time. 

This allows users to perform customized and composable compiler optimizations specifically tailored to single, arbitrary Julia packages.

Our library provides a simple, algebraically composable interface to help scientists in implementing and reasoning about semantics and all kinds of formal systems, by defining concise rewriting rules in pure, syntactically valid Julia on a high level of abstraction. Our implementation of equality saturation on e-graphs is based on the excellent, state-of-the-art technique implemented in the [egg](https://egraphs-good.github.io/) library, reimplemented in pure Julia.


## 3.0 Alpha

- [ ] Rewrite integration test files in [Literate.jl](https://github.com/fredrikekre/Literate.jl) format, becoming narrative tutorials available in the docs.
- [ ] Proof production algorithm: explanations.
- [x] Using new TermInterface.
- [x] Performance optimization: use vectors of UInt to internally represent terms in e-graphs.
- [x] Comprehensive suite of benchmarks that are run automatically on PR.
- [x] Complete overhaul of the rebuilding algorithm.

---

## We need your help! - Practical and Research Contributions

There's lot of room for improvement for Metatheory.jl, by making it more performant and by extending its features.
Any contribution is welcome!

**Performance**:
- Improving the speed of the e-graph pattern matcher. [(Useful paper)](https://arxiv.org/abs/2108.02290)
- Reducing allocations used by Equality Saturation.
- [#50](https://github.com/JuliaSymbolics/Metatheory.jl/issues/50) - Goal-informed [rule schedulers](https://github.com/JuliaSymbolics/Metatheory.jl/blob/master/src/EGraphs/Schedulers.jl): develop heuristic algorithms that choose what rules to apply at each equality saturation iteration to prune space of possible rewrites.  

**Features**:
- [#111](https://github.com/JuliaSymbolics/Metatheory.jl/issues/111) Introduce proof production capabilities for e-graphs. This can be based on the [egg implementation](https://github.com/egraphs-good/egg/blob/main/src/explain.rs).
- Common Subexpression Elimination when extracting from an e-graph [#158](https://github.com/JuliaSymbolics/Metatheory.jl/issues/158)
- Integer Linear Programming extraction of expressions.
- Pattern matcher enhancements: [#43 Better parsing of blocks](https://github.com/JuliaSymbolics/Metatheory.jl/issues/43), [#3 Support `...` variables in e-graphs](https://github.com/JuliaSymbolics/Metatheory.jl/issues/3), [#89 syntax for vectors](https://github.com/JuliaSymbolics/Metatheory.jl/issues/89)
- [#75 E-Graph intersection algorithm](https://github.com/JuliaSymbolics/Metatheory.jl/issues/75)

**Documentation**:
- Port more [integration tests](https://github.com/JuliaSymbolics/Metatheory.jl/tree/master/test/integration) to [tutorials](https://github.com/JuliaSymbolics/Metatheory.jl/tree/master/test/tutorials) that are rendered with [Literate.jl](https://github.com/fredrikekre/Literate.jl)
- Document [Functional Rewrite Combinators](https://github.com/JuliaSymbolics/Metatheory.jl/blob/master/src/Rewriters.jl) and add a tutorial.

## Real World Applications

Most importantly, there are many **practical real world applications** where Metatheory.jl could be used. Let's
work together to turn this list into some new Julia packages:


#### Integration with Symbolics.jl

Many features of this package, such as the classical rewriting system, have been ported from [SymbolicUtils.jl](https://github.com/JuliaSymbolics/SymbolicUtils.jl), and are technically the same. Integration between Metatheory.jl with Symbolics.jl **is currently
paused**, as we are waiting to reach consensus for the redesign of a common Julia symbolic term interface, [TermInterface.jl](https://github.com/JuliaSymbolics/TermInterface.jl). 

TODO link discussion when posted

An integration between Metatheory.jl and [Symbolics.jl](https://github.com/JuliaSymbolics/Symbolics.jl) is possible and has previously been shown in the ["High-performance symbolic-numerics via multiple dispatch"](https://arxiv.org/abs/2105.03949) paper. Once we reach consensus for a shared symbolic term interface, Metatheory.jl can be used to:

- Rewrite Symbolics.jl expressions with **bi-directional equations** instead of simple directed rewrite rules.
- Search for the space of mathematically equivalent Symbolics.jl expressions for more computationally efficient forms to speed various packages like  [ModelingToolkit.jl](https://github.com/SciML/ModelingToolkit.jl) that numerically evaluate Symbolics.jl expressions.
- When proof production is introduced in Metatheory.jl, automatically search the space of a domain-specific equational theory to prove that Symbolics.jl expressions are equal in that theory. 
- Other scientific domains extending Symbolics.jl for system modeling.

#### Simplifying Quantum Algebras

[QuantumCumulants.jl](https://github.com/qojulia/QuantumCumulants.jl/) automates
the symbolic derivation of mean-field equations in quantum mechanics, expanding
them in cumulants and generating numerical solutions using state-of-the-art
solvers like [ModelingToolkit.jl](https://github.com/SciML/ModelingToolkit.jl)
and
[DifferentialEquations.jl](https://github.com/SciML/DifferentialEquations.jl). A
potential application for Metatheory.jl is domain-specific code optimization for
QuantumCumulants.jl, aiming to be the first symbolic simplification engine for
Fock algebras.


#### Automatic Floating Point Error Fixer


[Herbie](https://herbie.uwplse.org/) is a tool using equality saturation to automatically rewrites mathematical expressions to enhance
floating-point accuracy. Recently, Herbie's core has been rewritten using
[egg](https://egraphs-good.github.io/), with the tool originally implemented in
a mix of Racket, Scheme, and Rust. While effective, its usage involves multiple
languages, making it impractical for non-experts. The text suggests the theoretical
possibility of porting this technique to a pure Julia solution, seamlessly
integrating with the language, in a single macro `@fp_optimize` that fixes
floating-point errors in expressions just before code compilation and execution.

#### Automatic Theorem Proving in Julia

Metatheory.jl can be used to make a pure Julia Automated Theorem Prover (ATP)
inspired by the use of E-graphs in existing ATP environments like
[Z3](https://github.com/Z3Prover/z3), [Simplify](https://dl.acm.org/doi/10.1145/1066100.1066102) and [CVC4](https://en.wikipedia.org/wiki/CVC4), 
in the context of [Satisfiability Modulo Theories (SMT)](https://en.wikipedia.org/wiki/Satisfiability_modulo_theories). 

The two-language problem in program verification can be addressed by allowing users to define high-level
theories about their code, that are statically verified before executing the program. This holds potential for various applications in
software verification, offering a flexible and generic environment for proving
formulae in different logics, and statically verifying such constraints on Julia
code before it gets compiled (see
[Mixtape.jl](https://github.com/JuliaCompilerPlugins/Mixtape.jl)).

To develop such a package, Metatheory.jl needs:

- Introduction of Proof Production in equality saturation.
- SMT in conjunction with a SAT solver like [PicoSAT.jl](https://github.com/sisl/PicoSAT.jl)
- Experiments with various logic theories and software verification applications.

#### Other potential applications

Many projects that could potentially be ported to Julia are listed on the [egg website](https://egraphs-good.github.io/).
A simple search for ["equality saturation" on Google Scholar](https://scholar.google.com/scholar?hl=en&q="equality+saturation") shows many new articles that leverage the techniques used in this packages. 

PLDI is a premier academic forum in the field of programming languages and programming systems research, which organizes an [e-graph symposium](https://pldi23.sigplan.org/home/egraphs-2023) where many interesting research and projects have been presented.

--- 

## Theoretical Developments

There's also lots of room for theoretical improvements to the e-graph data structure and equality saturation rewriting.  

#### Associative-Commutative-Distributive e-matching

In classical rewriting SymbolicUtils.jl offers a mechanism for matching expressions with associative and commutative operations: [`@acrule`](https://docs.sciml.ai/SymbolicUtils/stable/manual/rewrite/#Associative-Commutative-Rules) - a special kind of rule that considers all permutations and combinations of arguments. In e-graph rewriting in Metatheory.jl, associativity and commutativity have to be explicitly defined as rules. However, the presence of such rules, together with distributivity, will likely cause equality saturation to loop infinitely. See ["Why reasonable rules can create infinite loops"](https://github.com/egraphs-good/egg/discussions/60) for an explanation.

Some workaround exists for ensuring termination of equality saturation: bounding the depth of search, or merge-only rewriting without introducing new terms (see ["Ensuring the Termination of EqSat over a Terminating Term Rewriting System"](https://effect.systems/blog/ta-completion.html)). 

There's a few theoretical questions left:

- **What kind of rewrite systems terminate in equality saturation**?
- Can associative-commutative matching be applied efficiently to e-graphs while avoiding combinatory explosion?
- Can e-graphs be extended to include nodes with special algebraic properties, in order to mitigate the downsides of non-terminating systems? 

--- 

## Recommended Readings - Selected Publications

- The [Metatheory.jl manual](https://juliasymbolics.github.io/Metatheory.jl/stable/) 
- **OUT OF DATE**: The [Metatheory.jl introductory paper](https://joss.theoj.org/papers/10.21105/joss.03078#) gives a brief high level overview on the library and its functionalities.
- The Julia Manual [metaprogramming section](https://docs.julialang.org/en/v1/manual/metaprogramming/) is fundamental to understand what homoiconic expression manipulation is and how it happens in Julia.
- An [introductory blog post on SIGPLAN](https://blog.sigplan.org/2021/04/06/equality-saturation-with-egg/) about `egg` and e-graphs rewriting.
- [egg: Fast and Extensible Equality Saturation](https://dl.acm.org/doi/pdf/10.1145/3434304) contains the definition of *E-Graphs* on which Metatheory.jl's equality saturation rewriting backend is based. This is a strongly recommended reading.
- [High-performance symbolic-numerics via multiple dispatch](https://arxiv.org/abs/2105.03949): a paper about how we used Metatheory.jl to optimize code generation in [Symbolics.jl](https://github.com/JuliaSymbolics/Symbolics.jl)
- [Automated Code Optimization with E-Graphs](https://arxiv.org/abs/2112.14714). Alessandro Cheli's Thesis on Metatheory.jl 

## Contributing

If you'd like to give us a hand and contribute to this repository you can:
- Find a high level description of the project architecture in [ARCHITECTURE.md](https://github.com/juliasymbolics/Metatheory.jl/blob/master/ARCHITECTURE.md)
- Read the contribution guidelines in [CONTRIBUTING.md](https://github.com/juliasymbolics/Metatheory.jl/blob/master/CONTRIBUTING.md)

## Installation

You can install the stable version:
```julia
julia> using Pkg; Pkg.add("Metatheory")
```

Or you can install the development version (recommended by now for latest bugfixes)
```julia
julia> using Pkg; Pkg.add(url="https://github.com/JuliaSymbolics/Metatheory.jl")
```

## Documentation

Extensive Metatheory.jl is available [here](https://juliasymbolics.github.io/Metatheory.jl/dev)

## Citing

If you use Metatheory.jl in your research, please [cite](https://github.com/juliasymbolics/Metatheory.jl/blob/master/CITATION.bib) our works.

--- 

# Sponsors

If you enjoyed Metatheory.jl and would like to help, you can donate a coffee or choose place your logo and name in this page. [See 0x0f0f0f's Github Sponsors page](https://github.com/sponsors/0x0f0f0f/)!

<p align="center">
<a href="https://planting.space"> 
    <img width="300px" src="https://raw.githubusercontent.com/juliasymbolics/Metatheory.jl/master/.github/plantingspace.png"/>
</a>
</p>
