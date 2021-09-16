module Rules
    using TermInterface
    using Parameters
    using AutoHashEquals
    using Combinatorics: permutations, combinations

    using ..Util
    using ..EMatchCompiler
    using ..Patterns
    import Base.==

    include("rule_types.jl")
    include("rewriterule.jl")
    include("equalityrule.jl")
    include("unequalrule.jl")
    include("dynamicrule.jl")
    include("acrule.jl")
    # export Rule
    export SymbolicRule
    export RewriteRule
    export BidirRule
    export EqualityRule
    export UnequalRule
    export DynamicRule
    export AbstractRule
    export ACRule
    export @acrule, @ordered_acrule


    include("utils.jl")
    include("matchers.jl")
end