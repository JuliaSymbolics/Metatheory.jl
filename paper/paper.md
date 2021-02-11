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

The Julia programming language brought a fresh and new approach for technical computing, disrupting the popular conviction that a programming language cannot be very high level and performant at the same time. One of the most pragmatic features of Julia is the metaprogramming and macro interface, allowing to generate and manipulate reflective Julia expressions programmatically similarly to LISP idioms such as R5RS Scheme.

We introduce Metatheory.jl: a lightweight,
general purpose metaprogramming and algebraic (symbolic) computation library for the Julia programming language, designed for taking advantage of the powerful Julia reflection capabilities (often referred to as homoiconicity) to bridge the gap between symbolic mathematics, abstract interpretation, equational reasoning, compiler optimization, superoptimization and advanced homoiconic pattern matching features.

Metatheory.jl provides a simple, algebraically composable interface for defining rewriting rules and equational theories. Theories can then be executed with two composable rewriting backends. The first backend relies on a *classic* pattern matcher [@matchcore] that may be familiar to users of languages in the ML family. It is suitable for regular, deterministic recursive algorithms that intensively use pattern matching on syntax trees, for example, defining programming language interpreters from operational or denotational semantics. When using this classical approach, commonly encountered equational rewriting rules, even just commutative and associative properties of basic algebraic structures, may cause the recursive rewriting algorithms to loop indefinitely, and have historically required extensive reasoning for ordering and arranging rules in rewriting system.

This is where the other backend for Metatheory.jl comes into play. As the core of our contribution, the equality saturation backend allows programmers to define equational theories in pure Julia without worrying about rule ordering and structuring, by relying on state-of-the-art equality saturation techniques [@egg] for efficiently computing and analyzing all possible equivalent expressions. The latter backend is suitable for partial evaluators, symbolic mathematics, theorem proving and superoptimizers. The egg library [@egg] is the first ever implementation of generic and extensible e-graphs (TODO cita), which also provides novel
amortized algorithms for performant equivalence saturation and expression analysis.

Differently from the original rust implementation of *egg*, which handles languages defined as rust strings, our system manipulates homoiconic Julia expressions, and therefore fully leverages the Julia subtyping mechanism (TODO cita benchung) to allow programmers to include type assertions in the left hand of rewriting rules, and to build expressions containing all possible values, types and data structures supported by Julia.

Thanks to the built-in support for LaTeX-like abbreviations for mathematical symbols in many editors and the Julia REPL, parsed as regular unary and binary operators by the language, our system is meant to help scientists in the task of implementing and reasoning about formal systems, by defining rewriting rules and equational theories that bear a strong
resemblance with mathematical formalisms encountered in literature.

Systems modeled with natural deduction rules often need to maintain additional information, such as the types of variables or logical statements, in additional data structures. With Metatheory.jl, modeling such information and conditional rules is easy: it is possible to check conditions on runtime values or to read and write from external data structures during rewriting. The analysis mechanism borrowed from egg [@egg] even allows to attach additional analysis metadata such as logical statements to expressions on-the-fly during e-graph saturation.

When using the equality saturation (e-graph) backend, extraction can be performed as an on-the-fly e-graph analysis or after saturation. Users
can define their own, or choose between a variety of predefined cost functions for automatically choosing the most fitting expression from the congruence closure represented by an e-graph.

A goal of Metatheory is to be easy to use, highly composable and fast: the first-class pattern matching system generates callable functions by bypassing Julia's world age problem (TODO cita benchung) thanks to the small
RuntimeGeneratedFunctions.jl utility library [@rgf].

Metatheory.jl can run and transform expressions at both
compile and run time. Most importantly, our solution strives for *simplicity*. The general workflow for using Metatheory.jl is:
* Define rewrite and equational theories with the `@theory` macro.
* Recursively rewrite expressions or saturate and analyze e-graphs.
* Compose those steps as regular Julia functions to build optimizers, interpreters, compilers, symbolic engines, theorem provers and all sorts of
metaprogramming systems.

## A Concise Example of a Mathematical Theory

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

Recently, many applications of equality saturation have proven useful
and promising for optimization tasks. (TODO cita herbie e tensat) We are confident that with an equality saturation engine fully integrated in an homoiconic language such as Julia, many new frontiers of metaprogramming could be explored in future works, in an elegant, performant and concise way.    

# Acknowledgements

We acknowledge Christopher Rackauckas and Christopher Foster for their efforts in developing RuntimeGeneratedFunctions [@rgf], Taine Zhao for developing MLStyle [@mlstyle] and MatchCore [@matchcore] and support from Philip Zucker during the development of the project and his original idea of implementing E-Graphs in Julia.

# References
