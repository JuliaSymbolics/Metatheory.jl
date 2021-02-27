"Type representing a cache of [`RuntimeGeneratedFunctions`](@ref) corresponding
to right hand sides of dynamic rules"
const RhsFunCache = Dict{Rule, Tuple{Vector{Symbol}, Function}}

import ..closure_generator
"""
Generates a tuple containing the list of formal parameters (`Symbol`s)
and the [`RuntimeGeneratedFunction`](@ref) corresponding to the right hand
side of a `:dynamic` [`Rule`](@ref).
"""
function genrhsfun(rule::Rule, mod::Module)
    # remove type assertions in left hand
    lhs = df_walk( x -> (isexpr(x, :(::)) ? x.args[1] : x), rule.left; skip_call=true )

    # collect variable symbols in left hand
    lhs_vars = Set{Symbol}()
    df_walk( x -> (if x isa Symbol; push!(lhs_vars, x); end; x), rule.left; skip_call=true )
    params = Expr(:tuple, :_egraph, lhs_vars...)

    ex = :($params -> $(rule.right))
    (collect(lhs_vars), closure_generator(mod, ex))
end
