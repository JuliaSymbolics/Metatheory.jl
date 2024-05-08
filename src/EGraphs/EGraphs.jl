module EGraphs

include("../docstrings.jl")

using TermInterface
using TimerOutputs
using Metatheory.Patterns
using Metatheory.Rules
using Metatheory.VecExprModule

using Metatheory: alwaystrue, cleanast, UNDEF_ID_VEC, maybe_quote_operation, OptBuffer

import Metatheory: to_expr

include("unionfind.jl")
export UnionFind

include("uniquequeue.jl")

include("egraph.jl")
export Id,
  EClass, find, lookup, arity, EGraph, merge!, in_same_class, addexpr!, rebuild!, has_constant, get_constant, lookup_pat

include("extract.jl")
export extract!, astsize, astsize_inv


include("Schedulers.jl")
export Schedulers
using .Schedulers

include("saturation.jl")
export SaturationParams, saturate!, areequal, @areequal, @areequalg

end
