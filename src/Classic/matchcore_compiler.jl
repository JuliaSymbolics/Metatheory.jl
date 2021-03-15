# core mechanism of extending Taine Zhao's @thautwarm 's MatchCore pattern matching.

using MatchCore


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

c_right(v::Symbol, s) = Base.isbinaryoperator(v) ? v : dollar(v) #(v ∈ s ? dollar(v) : v)
function c_right(v::Expr, s)
    v.head ∈ add_dollar ? dollar(v) : v
end
c_right(v::QuoteNode, s) = v.value isa Symbol ? v.value : v
c_right(v, s) = v #ignore other types

# add dollar in front of the expressions with those symbols as head
const add_dollar = [:(::), :(...)]
# don't walk down on these symbols
const skips = [:(::), :(...)]

# Compile rules from Metatheory format to MatchCore format
function compile_rule(rule::Rule)::Expr
	patvars = Vector{Symbol}()
    le = df_walk(c_left, rule.left, patvars; skip=skips, skip_call=true) |> quot

	if rule.mode == :equational
		error("equational rules not yet supported by classic rewriting backend." *
			"Knuth-Bendix completion algorithm has not yet been implemented.")
    elseif rule.mode == :dynamic # regular pattern matching
        # right side not quoted! needed to evaluate expressions in right hand.
		ll = remove_assertions(rule.left)
		re = quote
			_lhs_expr = $(Meta.quot(ll));
			$(rule.right)
		end
    elseif rule.mode == :rewrite
		# right side is quoted, symbolic replacement
        re = df_walk(c_right, rule.right, patvars; skip=skips, skip_call=true) |> quot
	else
        error(`rule "$e" is not in valid form.\n`)
    end

    return :($le => $re)
end

# catch-all for reductions
const identity_axiom = :($(quot(dollar(:i))) => i)

# TODO analyse theory before compiling. Identify associativity and commutativity
# and other loop-creating problems. Generate a pattern matching block with the
# correct rule order and expansions for associativity and distributivity
# import Iterators: flatten. Knuth-Bendix completion??

function theory_block(t::Vector{Rule})
	tn = Vector{Expr}()

	for r ∈ t
		push!(tn, compile_rule(r))
		if r.mode == :equational
			mirrored = Rule(r.right, r.left, r.expr, r.mode, nothing)
			push!(tn, compile_rule(mirrored))
		end
	end

	block(tn..., identity_axiom)
end

"""
Compile a theory to a closure that does the pattern matching job
Returns a RuntimeGeneratedFunction, which does not use eval and
is as fast as a regular Julia anonymous function 🔥
"""
function compile_theory(theory::Vector{Rule}, mod::Module; __source__=LineNumberNode(0))
    # generate an unique parameter name
    parameter = Meta.gensym(:reducing_expression)
    block = theory_block(theory)

    matching = MatchCore.gen_match(parameter, block, __source__, mod)
    matching = MatchCore.AbstractPatterns.init_cfg(matching)

    ex = :(($parameter) -> $matching)
    closure_generator(mod, ex)
end

"""
Compile a theory at runtime to a closure that does the pattern matching job
"""
macro compile_theory(theory)
    gettheory(theory, __module__)
end

# Retrieve a theory from a module at compile time. Not exported
function gettheory(var, mod; compile=true)
	t = nothing
    if Meta.isexpr(var, :block) # @matcher begine rules... end
		t = rmlines(macroexpand(mod, var)).args .|> Rule
	else
		t = mod.eval(var)
	end

	if compile && !(t isa Function)
		t = compile_theory(t, mod)
	end

	return t
end
