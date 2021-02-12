---
title: 'Metatheory.jl: Fast and Elegant Algebraic Computation in Julia with Extensible Equality Saturation'
tags:
  - Julia
  - compiler
  - symbolic
  - algebra
  - rewriting
  - optimization
authors:
  - name: Alessandro Cheli #^[Custom footnotes for e.g. denoting who the corresponding author is can be included like this.]
    orcid: 0000-0002-8122-9469
    affiliation: "1, 2" # (Multiple affiliations must be quoted)
affiliations:
 - name: Undergraduate Student, University of Pisa
   index: 1
 - name: Independent Researcher
   index: 2
date: 11 February 2021
bibliography: paper.bib

---

# Summary

![The Ouroboros Wyvern. Public Domain Illustration by Lucas Jennis, 1625.\label{fig:dragon}](dragon.jpg){ width=30% }

The Julia programming is a fresh approach to technical computing [@bezanson2017julia], disrupting the popular conviction that a programming language cannot be very high level and performant at the same time. Some of the most practical features of Julia are metaprogramming support and an excellent macro system, allowing for programmatic generation and manipulation of Julia expressions as first class values in the core language, with a well known paradigm similar to LISP idioms such as Scheme,
a programming language property colloquially referred to as *homoiconicity*.

We introduce Metatheory.jl: a powerful,
general purpose metaprogramming and algebraic computation library for the Julia programming language, designed to take advantage of the powerful reflection capabilities to bridge the gap between symbolic mathematics,
abstract interpretation, equational reasoning, optimization, composable compiler transforms and advanced homoiconic pattern matching features. Intuitively, Metatheory.jl transforms Julia expressions in other Julia expressions, and can do so at both compile and run time.
Our library provides a simple, algebraically composable interface to help scientists in implementing and reasoning about equational and formal systems, by defining rewriting rules and equational theories.

Rewrite rules are defined as regular Julia expressions, manipulating syntactically valid Julia expressions: since Julia supports LaTeX-like abbreviations of UTF8 mathematical symbols as valid operators and symbols,
rules and theories in Metatheory.jl bear a strong structural and visual resemblance with mathematical formalisms encountered in paper literature.


Theories can then be executed through two, highly composable, rewriting backends. The first backend relies on a *classic* recursive AST pattern match-and-replace algorithm, built on top of the [@matchcore] pattern matcher, this approach may be familiar to programmers used to languages in the ML family. This backend is suitable for deterministic recursive algorithms that intensively use pattern matching on syntax trees, for example, defining programming language interpreters from operational or denotational semantics. Nevertheless, when using this classical approach, even trivial equational rules such as commutativity and associativity may cause the rewriting algorithm to loop indefinitely, or to return unexpected results. This has been historically known as *rewrite order*, and is well known for requiring extensive user reasoning for ordering and structuring rules to ensure confluence of a rewriting system.

## E-Graphs and Equality Saturation

This is where the other back-end for Metatheory.jl comes into play. As the core of our contribution, the equality saturation back-end allows programmers to define equational theories in pure Julia without worrying about rule ordering and structuring, by relying on state-of-the-art techniques for equality saturation over e-graphs [@egg].
Given a theory of rewriting and equational rules, e-graphs compactly represents many equivalent programs. Saturation iteratively applies an e-graph specific pattern matcher to efficiently compute (and analyze) all possible equivalent expressions contained in the e-graph congruence closure. The latter back-end is suitable for partial evaluators, symbolic mathematics, static analysis, theorem proving and superoptimizers.

The original egg library [@egg] is
known to be the first implementation of generic and extensible e-graphs [@nelson1980fast], the contributions of [@egg] also include novel amortized algorithms for fast and efficient equivalence saturation and analysis.
Differently from the original rust implementation of *egg*, which handles expressions defined as rust strings and `enum`, our system manipulates homoiconic Julia expressions, and can therefore fully leverage on the Julia subtyping mechanism [@zappa2018julia], allowing programmers to build expressions containing not only symbols, but all kinds of literal values.
This permits rewriting and analyses to be efficiently based on runtime data contained in expressions. Most importantly, users can and are encouraged to include type assertions in the left hand of rewriting rules.

A project goal of Metatheory, other than being to be easy to use and composable, is to be fast and efficient: the first-class pattern matching system and the generation of e-graph analyses from theories both rely on RuntimeGeneratedFunctions.jl [@rgf], generating callable functions at runtime that efficiently bypass Julia's world age problem [@belyakova2020world] with the full performance of a standard Julia anonymous function.


## Analyses and Extraction

With Metatheory.jl, modeling analyses and conditional/dynamic rewrites is easy and straightforward: it is possible to check conditions on runtime values or to read and write from external data structures during rewriting. The analysis mechanism described in egg and re-implemented in our contribution lets users define ways to compute additional analysis metadata from an arbitrary semi-lattice domain, such as costs of nodes or logical statements attached to terms. Other than for inspection, analysis data can be used to modify expressions in the e-graph both during rewriting steps or after e-graph saturation.

Therefore using the equality saturation (e-graph) backend, extraction can be performed as an on-the-fly e-graph analysis or after saturation. Users
can define their own, or choose between a variety of predefined cost functions for automatically extracting the most fitting expressions from the congruence closure represented by an e-graph.


# Examples

Most importantly, our solution strives for *simplicity*. The general workflow for using Metatheory.jl is:

* Define rewrite and equational theories with the `@theory` macro.
* Recursively rewrite expressions or saturate and analyze e-graphs.
* Compose those steps as regular Julia functions to build optimizers, interpreters, compilers, symbolic engines, theorem provers and all sorts of
metaprogramming systems.

```
using Calculus: differentiate

t = @theory begin
  # these rules are purely syntactic rewrites
  a * a => 2a
  a * 1 => a

  # the e-graphs backend directly handles otherwise
  # troublesome rules, such as commutativity and
  # associativity without any issue
  a * b => b * a
  a + b => b + a

  # we leverage the type system in the pattern matcher
  # to evaluate sums of numbers, using dynamic `|>` rules
  a::Number + b::Number |> a + b
  a::Number * b::Number |> a * b
end
```

Note that all of the expressions manipulated by Metatheory.jl
are **syntactically valid** Julia expressions. Theories are built
using regular Julia expressions and manipulate other Julia expressions.
This allows for extreme conciseness of code and opens up for
many possible applications of rewriting and analysis of Julia code.

# Conclusion

Recently, many applications of equality saturation have proven useful
and promising for optimization tasks. Herbie [@panchekha2015automatically]
is a tool for automatically improving the precision of floating point expressions, which recently switched to using egg as the rewriting backend. TENSAT [@yang2021equality] employs egg to superoptimize neural networks' tensor graphs. However, Herbie requires interoperation between different languages. Re-implementing those case studies in pure homoiconic Julia with Metatheory.jl would probably be valid research contributions on their own. We are confident that a well integrated homoiconic equality saturation engine in pure Julia will permit exploration of many new metaprogramming applications, and allow them to be implemented in an elegant, performant and concise way.    

# Acknowledgements

We acknowledge Christopher Rackauckas and Christopher Foster for their efforts in developing RuntimeGeneratedFunctions [@rgf], Taine Zhao for developing MLStyle [@mlstyle] and MatchCore [@matchcore] and support from Philip Zucker during the development of the project and his original idea of implementing E-Graphs in Julia.

# References
