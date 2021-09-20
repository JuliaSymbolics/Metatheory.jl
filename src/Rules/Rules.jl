module Rules
    using TermInterface
    using Parameters
    using AutoHashEquals

    
    using ..EMatchCompiler
    using ..Patterns
    import Base.==
    import ..cleanast
    import ..binarize

    const EMPTY_DICT = Base.ImmutableDict{Int, Any}()

    include("rule_types.jl")
    include("rewriterule.jl")
    include("equalityrule.jl")
    include("unequalrule.jl")
    include("dynamicrule.jl")
    include("utils.jl")
    include("matchers.jl")

    # export Rule
    export SymbolicRule
    export RewriteRule
    export BidirRule
    export EqualityRule
    export UnequalRule
    export DynamicRule
    export AbstractRule



end