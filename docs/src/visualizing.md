# Visualizing E-Graphs

You can visualize e-graphs in VSCode by using [GraphViz.jl]()

All you need to do is to install GraphViz.jl and to evaluate an e-graph after including the extra script:

```julia
using GraphViz

include(dirname(pathof(Metatheory)) * "/extras/graphviz.jl")

algebra_rules = @theory a b c begin
  a * (b * c) == (a * b) * c
  a + (b + c) == (a + b) + c

  a + b == b + a
  a * (b + c) == (a * b) + (a * c)
  (a + b) * c == (a * c) + (b * c)

  -a == -1 * a
  a - b == a + -b
  1 * a == a

  0 * a --> 0
  a + 0 --> a

  a::Number * b == b * a::Number
  a::Number * b::Number => a * b
  a::Number + b::Number => a + b
end;

ex = :(a - a)
g = EGraph(ex)
params = SaturationParams(; timeout = 2)
saturate!(g, algebra_rules, params)
g
```

And you will see a nice e-graph drawing in the Julia Plots VSCode panel:

![E-Graph Drawing](/assets/graphviz.svg)