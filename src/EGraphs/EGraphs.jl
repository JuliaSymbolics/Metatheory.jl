module EGraphs

include("../docstrings.jl")

using DataStructures
using TermInterface
using TimerOutputs
using Metatheory:
  alwaystrue, cleanast, binarize, DEFAULT_BUFFER_SIZE, BUFFER, BUFFER_LOCK, MERGES_BUF, MERGES_BUF_LOCK, Bindings
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

export Sub

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
