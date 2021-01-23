# core mechanism of extending Taine Zhao's @thautwarm 's MatchCore pattern matching.

using MatchCore
#using GeneralizedGenerated
using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)

## compile (quote) left and right hands of a rule
# escape symbols to create MLStyle compatible patterns

# compile left hand of rule
# if it's the first time seeing v, add it to the "seen symbols" Set
# insert a :& expression only if v has not been seen before
function c_left(v::Symbol, s)
    if Base.isbinaryoperator(v) return v end
    (v ∉ s ? (push!(s, v); v) : amp(v)) |> dollar
end
c_left(v::Expr, s) = v.head ∈ add_dollar ? dollar(v) : v
# support symbol literals in left hand
c_left(v::QuoteNode, s) = v.value isa Symbol ? dollar(v) : v
c_left(v, s) = v # ignore other types

c_right(v::Symbol) = Base.isbinaryoperator(v) ? v : dollar(v)
function c_right(v::Expr)
    v.head ∈ add_dollar ? dollar(v) : v
end
c_right(v) = v #ignore other types

# add dollar in front of the expressions with those symbols as head
const add_dollar = [:(::), :(...)]
# don't walk down on these symbols
const skips = [:(::), :(...)]

# Compile rules from Metatheory format to MatchCore format
function compile_rule(rule::Rule)::Expr
    le = df_walk(c_left, rule.left, Set{Symbol}(); skip=skips, skip_call=true) |> quot
    #le = c_left(l, Set{Symbol}()) |> quot
    if rule.mode == :direct # regular pattern matching
        # right side not quoted! needed to evaluate expressions in right hand.
        re = rule.right
    elseif rule.mode == :rewrite # right side is quoted, symbolic replacement
        re = df_walk(c_right, rule.right; skip=skips, skip_call=true) |> quot
    else
        error(`rule "$e" is not in valid form.\n`)
    end

    return :($le => $re)
end

# catch-all for symbolic reductions
identity_axiom = :($(quot(dollar(:i))) => i)

theory_block(t::Vector{Rule}) = block(map(compile_rule, t)..., identity_axiom)

# Compile a theory to a closure that does the pattern matching job
# RETURNS A QUOTED CLOSURE WITH THE GENERATED MATCHING CODE! FASTER AF! 🔥
function compile_theory(theory::Vector{Rule}, mod::Module; __source__=LineNumberNode(0))
    # generate an unique parameter name
    parameter = Meta.gensym(:reducing_expression)

    block = theory_block(theory)

    matching = MatchCore.gen_match(parameter, block, __source__, mod)
    matching = MatchCore.AbstractPatterns.init_cfg(matching)

    ex = :(($parameter, world) -> $matching)
    #println(ex)
    @RuntimeGeneratedFunction(ex)
    #mk_function([parameter], [], matching)
end

# TODO GG does not work. ask Taine Zhao.
# function closurize(block, __source__, __module__)
#     mk_function(__module__, :(
#         param ->
#         #matching =
#         #matching =
#         MatchCore.AbstractPatterns.init_cfg(MatchCore.gen_match(param, block, __source__, __module__)))
#     )
# end

# TODO consider compiling at parse time and test.
# Compile a theory at runtime to a closure that does the pattern matching job
macro compile_theory(t)
    quote
        Metatheory.compile_theory($(esc(t)), $__module__)
    end
end
