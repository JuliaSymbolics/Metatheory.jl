# Extracting from an E-Graph

Extraction can be formulated as an [EGraph analysis](https://dl.acm.org/doi/pdf/10.1145/3434304),
or after saturation. A cost function can be provided.
Metatheory.jl already provides some simple cost functions,
such as `astsize`, which expresses preference for the smallest expressions.

Given the theory:

```@example extraction
using Metatheory
using Metatheory.Library
using Metatheory.EGraphs

@metatheory_init

comm_monoid = commutative_monoid(:(*), 1);
comm_group = @theory begin
    a + 0 => a
    a + b => b + a
    a + inv(a) => 0 # inverse
    a + (b + c) => (a + b) + c
end
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
	log(x * y) => log(x) + log(y)
	log(1) => 0
	log(:e) => 1
	:e^(log(x)) => x
end
fold = @theory begin
	a::Number + b::Number |> a + b
	a::Number * b::Number |> a * b
end
t = comm_monoid ∪ comm_group ∪ distrib ∪ powers ∪ logids ∪ fold ;
nothing # hide
```

We can extract an expression by using

```@example extraction
G = EGraph(:((log(e) * log(e)) * (log(a^3 * a^2))))
saturate!(G, t)
ex = extract!(G, astsize)
```

The second argument to `extract!` is a **cost function**. `astsize` is 
a cost function provided by default, which computes the size of expressions.

## Defining custom cost functions

**TODO**

## API Docs

```@autodocs
Modules = [EGraphs]
Pages = ["extraction.jl"]
```
