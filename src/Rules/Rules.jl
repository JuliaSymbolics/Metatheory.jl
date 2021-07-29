module Rules
    using TermInterface
    using ..Util
    using ..EMatchCompiler
    import ..closure_generator

    include("rule_types.jl")
    include("rule_cache.jl")
    include("rule_dsl.jl")
    include("exports.jl")
end