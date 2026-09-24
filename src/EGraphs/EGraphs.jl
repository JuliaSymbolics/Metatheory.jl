"""
    EGraphs

Equality graphs for retaining and saturating many equivalent representations
of a term.

Build an [`EGraph`](@ref Metatheory.EGraphs.EGraph), add terms with [`addexpr!`](@ref Metatheory.EGraphs.addexpr!), and call
[`saturate!`](@ref Metatheory.EGraphs.saturate!) with a rule theory. Custom analyses implement the generic
`make`, `join`, `modify!`, and `islazy` hooks documented in the analysis API.
"""
module EGraphs

include("../docstrings.jl")

import DataStructures: CircularDeque, LittleDict, OrderedDict
import TermInterface: arguments, arity, exprhead, istree, operation, similarterm, symtype
import TimerOutputs: TimerOutput, disable_timer!, print_timer, timeit
import Metatheory: cleanast
import Metatheory.Patterns: AbstractPat, PatTerm, PatVar, UnsupportedPatternException, isground
import Metatheory.Rules: AbstractRule, BidirRule, DynamicRule, EqualityRule, RewriteRule, UnequalRule

"""
    arity(term)

Return the number of child arguments in a term. This is the
TermInterface.arity function reexported for e-graph implementations.
"""
arity

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
import .Schedulers: AbstractScheduler, BackoffScheduler, cansaturate, cansearch, inform!, setiter!

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
