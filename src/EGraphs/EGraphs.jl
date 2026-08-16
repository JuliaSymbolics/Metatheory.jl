"""
    EGraphs

Equality graphs for retaining and saturating many equivalent representations
of a term.

Build an [`EGraph`](@ref), add terms with [`addexpr!`](@ref), and call
[`saturate!`](@ref) with a rule theory. Custom analyses implement the generic
`make`, `join`, `modify!`, and `islazy` hooks documented in the analysis API.
"""
module EGraphs

include("../docstrings.jl")

using DataStructures
using TermInterface
using TimerOutputs
using Metatheory: alwaystrue, cleanast, binarize
using Metatheory.Patterns
using Metatheory.Rules
using Metatheory.EMatchCompiler

include("intdisjointmap.jl")
export IntDisjointSet
export in_same_set

include("egraph.jl")
export AbstractENode
export ENodeLiteral
export ENodeTerm
export EClassId
export EClass
export hasdata
export getdata
export setdata!
export find
export lookup
export arity
export EGraph
export merge!
export in_same_class
export addexpr!
export rebuild!
export settermtype!
export gettermtype

include("analysis.jl")
export analyze!
export extract!
export astsize
export astsize_inv
export getcost!

include("Schedulers.jl")
export Schedulers
using .Schedulers

include("saturation.jl")
export SaturationGoal
export EqualityGoal
export reached
export SaturationParams
export saturate!
export areequal
export @areequal
export @areequalg

end
