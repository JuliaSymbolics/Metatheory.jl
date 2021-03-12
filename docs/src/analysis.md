# EGraph Analyses and Extraction

## Extracting from an E-Graph

Extraction can be formulated as an [EGraph analysis](https://dl.acm.org/doi/pdf/10.1145/3434304),
or after saturation. A cost function can be provided.
Metatheory.jl already provides some simple cost functions,
such as `astsize`, which expresses preference for the smallest expressions.

```julia
G = EGraph(:((log(e) * log(e)) * (log(a^3 * a^2))))
saturate!(G, t)
extractor = addanalysis!(G, ExtractionAnalysis, astsize)
ex = extract!(G, extractor)
ex == :(log(a) * 5)
```


## Complex Example

Let's see a more complex example: extracting the
smallest equivalent expression, from a
trivial mathematics theory

```julia
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
fold_add = @theory begin
	a::Number + b::Number |> a + b
end
t = comm_monoid ∪ comm_group ∪ distrib ∪ powers ∪ logids ∪ fold_mul ∪ fold_add
```
