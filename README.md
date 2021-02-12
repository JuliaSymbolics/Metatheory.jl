<p align="center">
<img width="400px" src="https://raw.githubusercontent.com/0x0f0f0f/Metatheory.jl/master/paper/dragon.jpg"/>
</p>

# Metatheory.jl

![CI](https://github.com/0x0f0f0f/Metatheory.jl/workflows/CI/badge.svg)

**Metatheory.jl** is a general purpose metaprogramming and algebraic computation library for the Julia programming language, designed to take advantage of the powerful reflection capabilities to bridge the gap between symbolic mathematics, abstract interpretation, equational reasoning, optimization, composable compiler transforms, and advanced
homoiconic pattern matching features.

Intuitively, Metatheory.jl transforms Julia expressions
in other Julia expressions and can achieve such at both compile and run time. This allows Metatheory.jl users to perform customized and composable compiler optimization specif-
ically tailored to single, arbitrary Julia packages.
Our library provides a simple, algebraically composable interface to help scientists in imple-
menting and reasoning about semantics and all kinds of formal systems, by defining concise rewriting rules in pure, syntactically valid Julia on a high level of abstraction.

If you use Metatheory.jl in your research, please [cite](https://github.com/0x0f0f0f/Metatheory.jl/blob/master/CITATION.bib) our works.

## Examples

Here are some of examples of the basic workflow of using Metatheory.jl. Theories are composable and reusable!

### Basic Symbolic Mathematics

```julia
# The e-graphs backend can directly handle associativity,
# commutativity and distributivity, rules that are
# otherwise known of causing loops in symbolic computations.
comm_monoid = @theory begin
    a * b => b * a
    a * 1 => a
    a * (b * c) => (a * b) * c
end

# Theories are just collections of rules, and can
# be composed as regular julia collections. The most
# useful way of composing theories is unioning
# them with the '∪' operator.
comm_group = @theory begin
    a + 0 => a
    a + b => b + a
    a + inv(a) => 0 # inverse
    a + (b + c) => (a + b) + c
end
distrib = @theory begin
    a * (b + c) => (a * b) + (a * c)
end
t = comm_monoid ∪ comm_group ∪ distrib

# With the e-graph backend, Metatheory.jl can prove simple equalities
# very efficiently. The `@areequal` macro takes a theory and some
# expressions and returns true iff the expressions are equal
# according to the theory. The following example returns true.
@areequal t (x+y)*(a+b) ((a*(x+y)) + b*(x+y)) ((x*(a+b)) + y*(a+b))

#

```

### A Tiny Imperative Programming Language Interpreter
