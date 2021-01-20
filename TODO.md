TODO:
* Extend first class binary operators from a theory `src/operators.jl`
* `@judgment` for natural deduction syntax style like racket's redex
* Abstract interface to allow interchangeable solvers .
* FIXME allow ∀ and ∃ as symbols
* Specify monoids commutativity


DONE:
* Deal WITH N-ARITY OF * AND + - `binarize` hack in `src/reduce.jl`
* FIXED runtime sym_reduce
* FIXED: PARSE TIME INNER REDUCTION DOES NOT WORK

COOL PROJECTS
  * Turing complete small functional language interpreter, small step
    (rewriting) and big step (semantic rules)
  * Lambda calculi cores
  * Small theorem prover, use |> and push! expressions into an array
  * ExprOptimization.jl genetic programming with a loss function https://nbviewer.jupyter.org/github/sisl/ExprOptimization.jl/blob/master/examples/symbolic_regression.ipynb
  * Generate a program in WHILE lang with genetic programming/crossentropy, that
    approximates π
