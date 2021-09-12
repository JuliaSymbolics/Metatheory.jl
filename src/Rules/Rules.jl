module Rules
    using TermInterface
    using ..Util
    using ..EMatchCompiler
    import ..closure_generator

    include("rule_types.jl")
    export Rule
    export SymbolicRule
    export RewriteRule
    export BidirRule
    export EqualityRule
    export UnequalRule
    export DynamicRule

    export Program
    export Instruction

    include("rule_dsl.jl")
    export Rule
    export AbstractRule
    export gettheory
    export @rule
    export @theory
    export @methodrule
    export @methodtheory
end