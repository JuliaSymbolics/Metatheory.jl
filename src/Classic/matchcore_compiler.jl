# core mechanism of extending Taine Zhao's @thautwarm 's MatchCore pattern matching.

using MatchCore


## compile (quote) left and right hands of a rule
# escape symbols to create MLStyle compatible patterns

# compile left hand of rule
# if it's the first time seeing p, add it to the "seen symbols" Set
# insert a :& expression only if p has been seen before
function compile_lhs(p::PatVar, seen)
	if p.name ∉ seen 
		push!(seen, p.name)
		return dollar(p.name)
	else
		return dollar(amp(p.name))
	end
end

function compile_lhs(p::PatLiteral{T}, seen) where T
	p.val
end
compile_lhs(p::PatTypeAssertion, seen) = 
	dollar(Expr(:(::), p.var.name, p.type))
compile_lhs(p::PatSplatVar, seen) = 
	dollar(Expr(:(...), p.var.name))


function compile_lhs(p::PatTerm, seen)
	cargs = map(x -> compile_lhs(x, seen), p.args)
	Expr(p.head, cargs...)
end



compile_rhs(p::PatVar) = dollar(p.name)
function compile_rhs(p::PatLiteral{T}) where T
    p.val
end
compile_rhs(p::PatTypeAssertion) = 
	dollar(Expr(:(::), p.var.name, p.type))
compile_rhs(p::PatSplatVar) = 
	dollar(Expr(:(...), p.var.name))


function compile_rhs(p::PatTerm)
	cargs =  map(x -> compile_rhs(x), p.args)
	Expr(p.head, cargs...)
end

# Compile rules from Metatheory format to MatchCore format
function compile_rule(rule::EqualityRule)
	error("equational rules not yet supported by classic rewriting backend." *
			"Knuth-Bendix completion algorithm has not yet been implemented.")
end

function compile_rule(rule::UnequalRule)
	error("inequality anti-rules are only available for the egraphs backend.")
end

function compile_rule(rule::RewriteRule)
	seen = Symbol[]
	lhs = Meta.quot(compile_lhs(rule.left, seen))
	rhs = Meta.quot(compile_rhs(rule.right))
	return :($lhs => $rhs)
end

function compile_rule(rule::DynamicRule)
	seen = Symbol[]
	lhs = Meta.quot(compile_lhs(rule.left, seen))
	rhs = quote
		# FIXME
		# _lhs_expr = $(Meta.quot(lhs));
		$(rule.right)
	end

	return :($lhs => $rhs)
end


# catch-all for reductions
const identity_axiom = :($(quot(dollar(:i))) => i)

# TODO analyse theory before compiling. Identify associativity and commutativity
# and other loop-creating problems. Generate a pattern matching block with the
# correct rule order and expansions for associativity and distributivity
# import Iterators: flatten. Knuth-Bendix completion??

function theory_block(t::Vector{<:Rule})
	tn = Vector{Expr}()

	for r ∈ t
		push!(tn, compile_rule(r))
	end

	block(tn..., identity_axiom)
end

"""
Compile a theory to a closure that does the pattern matching job
Returns a RuntimeGeneratedFunction, which does not use eval and
is as fast as a regular Julia anonymous function 🔥
"""
function compile_theory(theory::Vector{<:Rule}, mod::Module; __source__=LineNumberNode(0))
    # generate an unique parameter name
    parameter = Meta.gensym(:reducing_expression)
    block = theory_block(theory)

	# println(block)
	# dump(block; maxdepth=12)
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

const MATCHCORE_FUNCTION_CACHE = IdDict{Vector{<:Rule}, Function}()
const MATCHCORE_FUNCTION_CACHE_LOCK = ReentrantLock()

function gettheoryfun(t::Vector{<:Rule}, m::Module)
    lock(MATCHCORE_FUNCTION_CACHE_LOCK) do
        if !haskey(MATCHCORE_FUNCTION_CACHE, t)
            z = compile_theory(t, m)
            MATCHCORE_FUNCTION_CACHE[t] = z
        end
        return MATCHCORE_FUNCTION_CACHE[t]
    end
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
		t = gettheoryfun(t, mod)
	end

	return t
end
