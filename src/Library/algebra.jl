macro commutativity(op) 
	quote 
		@rule ($op)(~a, ~b) == ($op)(~b, ~a)
	end
end 

macro right_associative(op)
	quote 
		@rule ($op)(~a, $(op)(~b, ~c)) → ($op)($(op)(~a, ~b), ~c)
	end
end
macro left_associative(op) 
	quote 
		@rule ($op)($(op)(~a, ~b), c) → ($op)(~a, $(op)(~b, ~c))
	end
end

macro associativity_left(op) 
	quote 
		@rule ($op)(~a, $(op)(~b, ~c)) → ($op)($(op)(~a, ~b), ~c)
	end
end
macro associativity_right(op) 
	quote 
		@rule ($op)($(op)(~a, ~b), ~c) → ($op)(~a, $(op)(~b, ~c))
	end
end 

macro associativity(op) 
	quote 
		[
			(@associativity_left $op), 
			(@associativity_right $op)
		]
	end
end

macro identity_left(op, id) 
	quote 
		@rule ($op)($id, ~a) → ~a
	end
end

macro identity_right(op, id) 
	quote 
		@rule ($op)(~a, $id) → ~a 
	end
end

macro inverse_left(op, id, invop) 
	quote 
		@rule ($op)(($invop)(~a), ~a) → $id 
	end 
end
macro inverse_right(op, id, invop) 
	quote 
		@rule ($op)(~a, ($invop)(~a)) → $id 
	end 
end

# distributivity of two operations
# example: `@distrib (⋅) (⊕)`
macro distrib_left(outop, inop)
	# @assert Base.isbinaryoperator(outop)
	# @assert Base.isbinaryoperator(inop)
	quote 
		@rule ($outop)(~a, ($inop)(~b, ~c)) == ($inop)(($outop)(~a, ~b), ($outop)(~a, ~c))
	end
end

macro distrib_right(outop, inop)
	# @assert Base.isbinaryoperator(outop)
	# @assert Base.isbinaryoperator(inop)
	quote 
		@rule ($outop)(($inop)(~a, ~b), ~c) == ($inop)(($outop)(~a, ~c), ($outop)(~b, ~c))
	end
end

macro monoid(op, id)
	quote 
		[
			(@associativity_left(op)), 
			(@associativity_right(op)),
			(@identity_left(op, id)), 
			(@identity_right(op, id))
		]
	end
end

macro commutative_monoid(op, id)
	quote 
		[
			(@commutativity $op), 
			(@associativity_left $op),
			(@associativity_right $op), 
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
