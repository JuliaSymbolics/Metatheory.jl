module Rules
    using ..TermInterface
    using ..Util
    import ..closure_generator

    include("patterns.jl")
    include("patterns_syntax.jl")
    include("rule_types.jl")
    include("rule_cache.jl")
    include("rule_dsl.jl")
    include("exports.jl")
end