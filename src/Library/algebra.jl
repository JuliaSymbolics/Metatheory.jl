

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
