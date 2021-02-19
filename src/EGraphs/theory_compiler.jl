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
    lhs = df_walk( x -> (isexpr(x, :ematch_tassert) ? x.args[1] : x), rule.left; skip_call=true )

    # collect variable symbols in left hand
    lhs_vars = Set{Symbol}()
    df_walk( x -> (if x isa Symbol; push!(lhs_vars, x); end; x), rule.left; skip_call=true )
    params = Expr(:tuple, :_egraph, lhs_vars...)

    ex = :($params -> $(rule.right))
    (collect(lhs_vars), closure_generator(mod, ex))
end


# TODO is there anything better than eval to use here?
"""
When creating a theory, type assertions in the left hand contain symbols.
We want to replace the type symbols with the real type values, to fully support
the subtyping mechanism during pattern matching.
"""
function eval_types_in_assertions(x, mod::Module)
    if isexpr(x, :(::))
        !(x.args[1] isa Symbol) && error("Type assertion is not on metavariable")
        Expr(:ematch_tassert, x.args[1], mod.eval(x.args[2]))
    else x
    end
end
