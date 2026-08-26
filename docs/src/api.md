# API Documentation

## Metatheory

```@docs
Metatheory
rewrite
Metatheory.@matchable
Metatheory.@timer
Metatheory.@iftimer
Metatheory.@timerewrite
```

---

## Public modules and matcher compiler

```@docs
Metatheory.Library
Metatheory.Syntax
Metatheory.Patterns
Metatheory.Rules
Metatheory.Rewriters
Metatheory.EGraphs
Metatheory.EGraphs.Schedulers
Metatheory.EMatchCompiler
Metatheory.ematcher_yield
Metatheory.ematcher_yield_bidir
```

---

## Library

```@docs
Metatheory.Library.@commutativity
Metatheory.Library.@associativity
Metatheory.Library.@identity_left
Metatheory.Library.@identity_right
Metatheory.Library.@distrib_left
Metatheory.Library.@distrib_right
Metatheory.Library.@distrib
Metatheory.Library.@monoid
Metatheory.Library.@commutative_monoid
Metatheory.Library.@commutative_group
Metatheory.Library.@left_associative
Metatheory.Library.@right_associative
Metatheory.Library.@inverse_left
Metatheory.Library.@inverse_right
```

---

## Syntax

```@docs
Metatheory.Syntax.@rule
Metatheory.Syntax.@theory
Metatheory.Syntax.@slots
Metatheory.Syntax.@capture
```

---

## Patterns

```@docs
Metatheory.Patterns.AbstractPat
Metatheory.Patterns.PatVar
Metatheory.Patterns.PatTerm
Metatheory.Patterns.PatSegment
Metatheory.Patterns.patvars
Metatheory.Patterns.setdebrujin!
Metatheory.Patterns.isground
Metatheory.Patterns.UnsupportedPatternException
```

---

## Rules 

```@docs
Metatheory.Rules.SymbolicRule
Metatheory.Rules.RewriteRule
Metatheory.Rules.BidirRule
Metatheory.Rules.EqualityRule
Metatheory.Rules.UnequalRule
Metatheory.Rules.DynamicRule
Metatheory.Rules.AbstractRule
```

---

## Rewriters

```@docs
Metatheory.Rewriters.Empty
Metatheory.Rewriters.IfElse
Metatheory.Rewriters.If
Metatheory.Rewriters.Chain
Metatheory.Rewriters.RestartedChain
Metatheory.Rewriters.Fixpoint
Metatheory.Rewriters.Postwalk
Metatheory.Rewriters.Prewalk
Metatheory.Rewriters.PassThrough
```

---

## EGraphs

```@docs
Metatheory.EGraphs.IntDisjointSet
Metatheory.EGraphs.in_same_set
Metatheory.EGraphs.AbstractENode
Metatheory.EGraphs.ENodeLiteral
Metatheory.EGraphs.ENodeTerm
Metatheory.EGraphs.EClassId
Metatheory.EGraphs.EClass
Metatheory.EGraphs.hasdata
Metatheory.EGraphs.getdata
Metatheory.EGraphs.setdata!
Metatheory.EGraphs.find
Metatheory.EGraphs.lookup
Metatheory.EGraphs.arity
Metatheory.EGraphs.EGraph
Metatheory.EGraphs.merge!
Metatheory.EGraphs.in_same_class
Metatheory.EGraphs.addexpr!
Metatheory.EGraphs.rebuild!
Metatheory.EGraphs.settermtype!
Metatheory.EGraphs.gettermtype
Metatheory.EGraphs.analyze!
Metatheory.EGraphs.extract!
Metatheory.EGraphs.astsize
Metatheory.EGraphs.astsize_inv
Metatheory.EGraphs.getcost!
Metatheory.EGraphs.SaturationGoal
Metatheory.EGraphs.EqualityGoal
Metatheory.EGraphs.reached
Metatheory.EGraphs.SaturationParams
Metatheory.EGraphs.saturate!
Metatheory.EGraphs.areequal
Metatheory.EGraphs.@areequal
Metatheory.EGraphs.@areequalg
```

---

## EGraph Schedulers

```@docs
Metatheory.EGraphs.Schedulers.AbstractScheduler
Metatheory.EGraphs.Schedulers.SimpleScheduler
Metatheory.EGraphs.Schedulers.BackoffScheduler
Metatheory.EGraphs.Schedulers.ScoredScheduler
Metatheory.EGraphs.Schedulers.cansaturate
Metatheory.EGraphs.Schedulers.cansearch
Metatheory.EGraphs.Schedulers.inform!
Metatheory.EGraphs.Schedulers.setiter!
```

## EGraph analysis interfaces

```@docs
Metatheory.EGraphs.islazy
Metatheory.EGraphs.modify!
Metatheory.EGraphs.join
Metatheory.EGraphs.make
Metatheory.EGraphs.egraph_reconstruct_expression
Metatheory.binarize_rec
```

## Developer implementation API

These bindings support custom backends and analyses inside Metatheory's
implementation. They are documented for package developers; ordinary users
should prefer the public interfaces above.

```@docs
Metatheory.Rewriters.FixpointNoCycle
Metatheory.EGraphs.eqsat_step!
Metatheory.EGraphs.instantiate_actual_param!
Metatheory.EGraphs.preprocess
Metatheory.EGraphs.reachable
Metatheory.EGraphs.eqsat_search!
Metatheory.EGraphs.add!
Metatheory.Syntax.rewrite_rhs
Metatheory.Syntax.rmlines
```
