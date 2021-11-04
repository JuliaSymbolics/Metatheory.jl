# constructs a semantic theory about a commutative monoid
# A monoid whose operation is commutative is called a
# commutative monoid (or, less commonly, an abelian monoid).

include("docstrings.jl")

module Library

using Metatheory.Patterns
using Metatheory.Rules

macro associativity(op) 
	quote 
		[
			(@left_associative $op), 
			(@right_associative $op)
		]
	end
end

macro monoid(op, id)
	quote 
		[
			(@left_associative(op)), 
			(@right_associative(op)),
			(@identity_left(op, id)), 
			(@identity_right(op, id))
		]
	end
end

macro commutative_monoid(op, id)
	quote 
		[
			(@commutativity $op), 
			(@left_associative $op),
			(@right_associative $op), 
			(@identity_left $op $id)
		]
	end
end

# constructs a semantic theory about a an abelian group
# The definition of a group does not require that a ⋅ b = b ⋅ a
# for all elements a and b in G. If this additional condition holds,
# then the operation is said to be commutative, and the group is called an abelian group.
macro commutative_group(op, id, invop)
	# @assert Base.isbinaryoperator(op)
	# @assert Base.isunaryoperator(invop)
	quote 
		(@commutative_monoid $op $id) ∪ [@inverse_right $op $id $invop]
	end
end

macro distrib(outop, inop) 
	quote 
		[
			(@distrib_left $outop $inop), 
			(@distrib_right $outop $inop),
		]
	end
end


macro commutativity(op) 
	RewriteRule(
		PatTerm(:call, op, [PatVar(:a), PatVar(:b)], __module__), 
		PatTerm(:call, op, [PatVar(:b), PatVar(:a)], __module__))
end 

macro right_associative(op)
	RewriteRule(
		PatTerm(:call, op, [PatVar(:a), 
			PatTerm(:call, op, [PatVar(:b), PatVar(:c)], __module__)], __module__),
		PatTerm(:call, op, [
			PatTerm(:call, op, [PatVar(:a), PatVar(:b)], __module__), 
			PatVar(:c), 
			], __module__))
end
macro left_associative(op) 
	RewriteRule(
		PatTerm(:call, op, [
			PatTerm(:call, op, [PatVar(:a), PatVar(:b)], __module__), 
			PatVar(:c), 
			], __module__),
		PatTerm(:call, op, [PatVar(:a), 
			PatTerm(:call, op, [PatVar(:b), PatVar(:c)], __module__)], __module__))
end


macro identity_left(op, id) 
	RewriteRule(PatTerm(:call, op, [id, PatVar(:a)], __module__), PatVar(:a))
end

macro identity_right(op, id) 
	RewriteRule(PatTerm(:call, op, [PatVar(:a), id], __module__), PatVar(:a))
end

macro inverse_left(op, id, invop) 
	RewriteRule(PatTerm(:call, op, [
		PatTerm(:call, invop, [PatVar(:a)], __module__), PatVar(:a)], __module__), id) 
end
macro inverse_right(op, id, invop) 
	RewriteRule(PatTerm(:call, op, [
		PatVar(:a),
		PatTerm(:call, invop, [PatVar(:a)], __module__)], __module__), id)
end


# distributivity of two operations
# example: `@distrib (⋅) (⊕)`
macro distrib_left(outop, inop)
	EqualityRule(
		# left 
		PatTerm(:call, outop, [
			PatVar(:a),
			PatTerm(:call, inop, [PatVar(:b), PatVar(:c)], __module__)
		], __module__), 
		# right 
		PatTerm(:call, inop, [
			PatTerm(:call, outop, [PatVar(:a), PatVar(:b)], __module__),
			PatTerm(:call, outop, [PatVar(:a), PatVar(:c)], __module__),
		], __module__))

end

macro distrib_right(outop, inop)
	EqualityRule(
		# left 
		PatTerm(:call, outop, [
			PatTerm(:call, inop, [PatVar(:a), PatVar(:b)], __module__),
			PatVar(:c)
		], __module__), 
		# right 
		PatTerm(:call, inop, [
			PatTerm(:call, outop, [PatVar(:a), PatVar(:c)], __module__),
			PatTerm(:call, outop, [PatVar(:b), PatVar(:c)], __module__),
		], __module__))
end


# theory generation macros
export @commutativity
export @associativity
export @identity_left
export @identity_right
export @distrib_left
export @distrib_right
export @distrib
export @monoid
export @commutative_monoid
export @commutative_group

end
