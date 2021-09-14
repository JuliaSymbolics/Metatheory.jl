module Rules
    using TermInterface
    using ..Util
    using ..EMatchCompiler
    import ..closure_generator

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

    include("rule_dsl.jl")
    export Rule
    export AbstractRule
    export gettheory
    export @rule
    export @theory
    export @methodrule
    export @methodtheory

    include("utils.jl")
    include("matchers.jl")
end