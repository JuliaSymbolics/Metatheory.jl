
# TODO move this to an abstract type
# mutable struct Rule
#     left::Any
#     right::Any
#     patvars::Vector{Symbol}
#     expr::Expr # original expression
#     mode::Symbol # can be :symbolic or :dynamic
# end

# TODO dismantle equational rules in two symbolic rules for 
# easier scheduling



# iscond(e) = (isexpr(e, :call) && e.args[1] == :(==)) #||
#     #(isexpr(e, :call) && e.args[1] == :(≠))

# macro when(expr)
#     @assert isexpr(expr, :call)
#     op = expr.args[1]
#     expr = rmlines(expr)
#     if op == :⊢     # syntactical consequence. supported only in egraphs
#         conditions = []
#         env = expr.args[2]
#         # extract conditions from env
#         # support (a=b;c=d) [a=b c=d] and [a=b, c=d]
#         if isexpr(env, :block) || isexpr(env, :vect) || isexpr(env, :hcat)
#             for cond ∈ env.args
#                 if iscond(cond)
#                     push!(conditions, cond)
#                 else
#                     error("malformed condition $cond")
#                 end
#             end
#         # support a signle a=b or a≠b
#         elseif iscond(env)
#             push!(conditions, env)
#         else
#             error("malformed conditions $env")
#         end
#         # get rule on right
#         rule = expr.args[3]
#         op = gethead(rule)
#         mode = getmode(rule)
#         l, r = rule.args[isexpr(rule, :call) ? (2:3) : (1:2)]


#         #
#         # println(l)
#         # println(r)
#         # println(op)
#         # println(mode)
#         # println(conditions)

#         if mode != :symbolic && mode != :dynamic
#             error("only conditional dynamic or symbolic rules are supported")
#         end

#         cond = make_egraph_condition(conditions)
#         # println(cond)

#         if mode == :dynamic
#             ret = :(($op)($l, if $cond
#                 $r
#                 else _lhs_expr end)) |> esc |> rmlines
#             ret
#         end

#     end
# end

# """
# Generate a single expression containing an equality/inequality condition on the
# current egraph for a conditional rule and the `@when` macro
# """
# # TODO nun va bene, invece di find devi fare tutti gli addexpr
# # e poi controllare le uguaglianze sulle EClass alla fine. usa gensym
# function make_egraph_condition(conditions)
#     egraphed_conditions = []
#     for x ∈ conditions
#         op, l, r = x.args[1:3]

#         ll = df_walk( x -> (if x isa Symbol; dollar(x); end; x), l; skip_call=true )

#         l |> dump
#         ll |> dump

#         op == :≠ && (op = :(!=))
#         push!(egraphed_conditions,
#             :(($op)(find(_egraph, $l), find(_egraph, $r))))
#     end

#     foldr((x,y) -> :($x && $y), egraphed_conditions)
# end

# export @when
# export iscond
