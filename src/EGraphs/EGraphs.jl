module EGraphs

include("../docstrings.jl")

using ..TermInterface
using TimerOutputs
using Metatheory: alwaystrue, cleanast
using Metatheory.Patterns
using Metatheory.Rules
using Metatheory.EMatchCompiler

include("unionfind.jl")
export IntDisjointSet
export UnionFind

include("uniquequeue.jl")

include("egraph.jl")
export ENode
export EClassId
export EClass
export find
export lookup
export arity
export EGraph
export merge!
export in_same_class
export addexpr!
export rebuild!

include("extract.jl")
export extract!
export astsize
export astsize_inv


include("Schedulers.jl")
export Schedulers
using .Schedulers

include("saturation.jl")
export SaturationParams
export saturate!
export areequal
export @areequal
export @areequalg

end
