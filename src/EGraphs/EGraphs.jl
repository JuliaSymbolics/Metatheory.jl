module EGraphs

include("../docstrings.jl")

using TermInterface
using TimerOutputs
using Metatheory.Patterns
using Metatheory.Rules
using Metatheory.EMatchCompiler
using Metatheory.VecExprModule

using Metatheory: alwaystrue, cleanast, Bindings, UNDEF_ID_VEC, should_quote_operation

import Metatheory: to_expr, maybelock!, lookup_pat, has_constant, get_constant


include("unionfind.jl")
export UnionFind

include("uniquequeue.jl")

include("egraph.jl")
export Id
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
