module Rules
    using TermInterface
    using Parameters
    using AutoHashEquals

    
    using ..EMatchCompiler
    using ..Patterns
    import Base.==
    import ..cleanast
    import ..binarize

    include("rule_types.jl")
    include("rewriterule.jl")
    include("equalityrule.jl")
    include("unequalrule.jl")
    include("dynamicrule.jl")

    # export Rule
    export SymbolicRule
    export RewriteRule
    export BidirRule
    export EqualityRule
    export UnequalRule
    export DynamicRule
    export AbstractRule


    include("utils.jl")
    include("matchers.jl")
end