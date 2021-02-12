<p align="center">
<img width="400px" src="https://raw.githubusercontent.com/0x0f0f0f/Metatheory.jl/master/docs/dragon.jpg"/>
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
@areequal t (x+y)*(a+b) ((a*(x+y))+b*(x+y)) ((x*(a+b))+y*(a+b))

# We can use type assertions and dynamic rules, defined with the `|>`
# operator, to dynamically compute values in the right hand of expressions
fold_mul = @theory begin
    a::Number * b::Number |> a*b
end
t = comm_monoid ∪ fold_mul
@areequal t (3*4) 12

# Let's see a more complex example: extracting the
# smallest equivalent expression, basing from a
# trivial mathematics theory
distrib = @theory begin
	a * (b + c) => (a * b) + (a * c)
	(a * b) + (a * c) => a * (b + c)
end
powers = @theory begin
	a * a => a^2
	a => a^1
	a^n * a^m => a^(n+m)
end
logids = @theory begin
	log(a^n) => n * log(a)
	log(x * y) => log(x) * log(y)
	log(1) => 0
	log(:e) => 1
	:e^(log(x)) => x
end
fold_add = @theory begin
	a::Number + b::Number |> a + b
end
t = comm_monoid ∪ comm_group ∪ distrib ∪ powers ∪ logids ∪ fold_mul ∪ fold_add

# We can programmatically build and saturate an e-graph.
G = EGraph(:((log(e) * log(e)) * (log(a^3 * a^2))))
saturate!(G, t)
ex = extract!(G, astsize)

ex == :(5log(a))
```

### A Tiny Imperative Programming Language Interpreter

This example does not use the e-graphs backend. A recursive
algorithm is sufficient for interpreting expressions.
Note how we are representing semantics for a different programming language
by reusing the Julia AST data structure, and therefore efficiently reusing
the Julia parser for our new toy language.

See this [test file](https://github.com/0x0f0f0f/Metatheory.jl/blob/master/test/test_while_interpreter.jl).
