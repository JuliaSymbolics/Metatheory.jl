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

The Julia programming language is a fresh approach to technical computing [@bezanson2017julia], disrupting the popular conviction that a programming language cannot be very high level, easy to learn, and performant at the same time. One of the most practical features of Julia is the excellent metaprogramming and macro system, allowing for programmatic generation and manipulation of Julia expressions as first-class values in the core language, with a well-known paradigm similar to LISP idioms such as Scheme,
a programming language property colloquially referred to as *homoiconicity*.

We introduce Metatheory.jl: a general purpose metaprogramming and algebraic computation library for the Julia programming language, designed to take advantage of the powerful reflection capabilities to bridge the gap between symbolic mathematics,
abstract interpretation, equational reasoning, optimization, composable compiler transforms, and advanced homoiconic pattern matching features. Intuitively, Metatheory.jl transforms Julia expressions in other Julia expressions and can achieve such at both compile and run time. This allows Metatheory.jl users to perform customized and composable compiler optimization specifically tailored to single, arbitrary Julia packages. Our library provides a simple, algebraically composable interface to help scientists in implementing and reasoning about semantics and all kinds of formal systems, by defining concise rewriting rules in pure, syntactically valid Julia on a high level of abstraction.

Rewrite rules are defined as regular Julia expressions, manipulating other syntactically valid Julia expressions: since Julia supports LaTeX-like abbreviations of UTF8 mathematical symbols as valid operators and symbols,
rewrite theories in Metatheory.jl can bear a strong structural and visual resemblance to mathematical formalisms encountered in paper literature.


Theories can then be executed through two, highly composable, rewriting backends. The first backend relies on a *classic* fixed-point recursive iteration of AST, with a match-and-replace algorithm built on top of the [@matchcore] pattern matcher. This approach may be familiar to programmers already experienced in ML-like languages. This backend is suitable for deterministic recursive algorithms that intensively use pattern matching on syntax trees, for example, defining an interpreter from operational or denotational semantics. Nevertheless, when using this classical approach, even trivial equational rules such as commutativity and associativity may cause the rewriting algorithm to loop indefinitely, or to return unexpected results. This is known as *rewrite order* and is notoriously recognized for requiring extensive user reasoning about the ordering and structuring of rules to ensure termination.

## E-Graphs and Equality Saturation

This is what the other back-end for Metatheory.jl is designed to solve. As the core of our contribution, the equality saturation back-end allows programmers to define equational theories in pure Julia without worrying about rule ordering and structuring, by relying on state-of-the-art techniques for equality saturation over *e-graphs* adapted from the `egg` rust library [@egg].
Provided with a theory of equational rewriting rules, *e-graphs* compactly represent many equivalent programs. Saturation iteratively executes an e-graph specific pattern matcher to efficiently compute (and analyze) all possible equivalent expressions contained in the e-graph congruence closure. This latter back-end is suitable for partial evaluators, symbolic mathematics, static analysis, theorem proving and superoptimizers.

![These four e-graphs represent the process of equality saturation, adding many equivalent ways to write $(a \times 2) / 2$ after each iteration. Credits to Max Willsey (@egg).\label{fig:egggg}](egraphs.png)


The original `egg` library [@egg] is
known to be the first implementation of generic and extensible e-graphs [@nelson1980fast], the contributions of `egg` include novel amortized algorithms for fast and efficient equivalence saturation and analysis.
Differently from the original rust implementation of `egg`, which handles expressions defined as rust strings and data structures, our system directly manipulates homoiconic Julia expressions, and can therefore fully leverage the Julia subtyping mechanism [@zappa2018julia], allowing programmers to build expressions containing not only symbols but all kinds of Julia values.
This permits rewriting and analyses to be efficiently based on runtime data contained in expressions. Most importantly, users can and are encouraged to include type assertions in the left hand of rewriting rules in theories.

A project goal of Metatheory, other than being to be easy to use and composable, is to be fast and efficient: the first-class pattern matching system and the generation of e-graph analyses from theories both rely on RuntimeGeneratedFunctions.jl [@rgf], generating callable functions at runtime that efficiently bypass Julia's world age problem [@belyakova2020world] with the full performance of a standard Julia anonymous function.


## Analyses and Extraction

With Metatheory.jl, modeling analyses and conditional/dynamic rewrites is easy and straightforward: it is possible to check conditions on runtime values or to read and write from external data structures during rewriting. The analysis mechanism described in egg and re-implemented in our contribution lets users define ways to compute additional analysis metadata from an arbitrary semi-lattice domain, such as costs of nodes or logical statements attached to terms. Other than for inspection, analysis data can be used to modify expressions in the e-graph both during rewriting steps or after e-graph saturation.

Therefore using the equality saturation (e-graph) backend, extraction can be performed as an on-the-fly e-graph analysis or after saturation. Users
can define their own, or choose between a variety of predefined cost functions for automatically extracting the most fitting expressions from the congruence closure represented by an e-graph.

# Conclusion

Many applications of equality saturation have been recently published, tailoring advanced optimization tasks. Herbie [@panchekha2015automatically]
is a tool for automatically improving the precision of floating point expressions, which recently switched to `egg` as the core rewriting backend. In [@yang2021equality], authors used `egg` to superoptimize tensor signal flow graphs describing neural networks. However, Herbie requires interoperation and conversion of expressions between different languages and libraries. Implementing similar case studies in pure Julia would make valid research contributions on their own. We are confident that a well-integrated and homoiconic equality saturation engine in pure Julia will permit exploration of many new metaprogramming applications, and allow them to be implemented in an elegant, performant and concise way.    

# Acknowledgements

We acknowledge Max Willsey and contributors for their work on the original `egg` library [@egg], Christopher Rackauckas and Christopher Foster for their efforts in developing RuntimeGeneratedFunctions [@rgf], Taine Zhao for developing MLStyle [@mlstyle] and MatchCore [@matchcore], and Philip Zucker for his original idea of implementing E-Graphs in Julia [@philzuck1, @philzuck2] and support during the development of the project.

# References
