module Rules
    using ..TermInterface
    using ..Util

    include("patterns.jl")
    include("rule_types.jl")
    include("rule_cache.jl")
    include("rule_dsl.jl")
    include("exports.jl")
end