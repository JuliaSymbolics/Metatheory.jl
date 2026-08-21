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

```@autodocs
Modules = [Metatheory.Library]
```

---

## Syntax

```@autodocs
Modules = [Metatheory.Syntax]
```

---

## Patterns

```@autodocs
Modules = [Metatheory.Patterns]
```

---

## Rules 

```@autodocs
Modules = [Metatheory.Rules]
```

---

## Rewriters

```@autodocs
Modules = [Metatheory.Rewriters]
```

---

## EGraphs

```@autodocs
Modules = [Metatheory.EGraphs]
```

---

## EGraph Schedulers

```@autodocs
Modules = [Metatheory.EGraphs.Schedulers]
```

## EGraph analysis interfaces

```@docs
Metatheory.EGraphs.islazy
Metatheory.EGraphs.modify!
Metatheory.EGraphs.join
Metatheory.EGraphs.make
Metatheory.EGraphs.analyze!
Metatheory.EGraphs.extract!
Metatheory.EGraphs.egraph_reconstruct_expression
```
