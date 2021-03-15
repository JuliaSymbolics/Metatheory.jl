fix_literal(id) = if id isa Symbol; Meta.quot(id) else id end
(~)(id) = fix_literal(id)

commutativity(op) = :( ($op)(a, b) == ($op)(b, a) ) |> Rule
right_associative(op) = :( ($op)(a, $(op)(b,c)) => ($op)($(op)(a,b), c) ) |> Rule
left_associative(op) = :( ($op)($(op)(a,b), c) => ($op)(a, $(op)(b,c)) ) |> Rule

associativity(op) = :( ($op)(a, $(op)(b,c)) == ($op)($(op)(a,b), c) ) |> Rule

identity_left(op, id) = let id = ~id; :( ($op)($id, a) => a ) |> Rule end
identity_right(op, id) = let id = ~id; :( ($op)(a, $id) => a ) |> Rule end

inverse_left(op, id, invop) = let id = ~id; :( ($op)(($invop)(a), a) => $id ) |> Rule end
inverse_right(op, id, invop) = let id = ~id; :( ($op)(a, ($invop)(a)) => $id ) |> Rule end

# distributivity of two operations
# example: `@distrib (⋅) (⊕)`
function distrib_left(outop, inop)
	@assert Base.isbinaryoperator(outop)
	@assert Base.isbinaryoperator(inop)
	:( ($outop)(a, ($inop)(b,c)) == ($inop)(($outop)(a,b),($outop)(a,c)) ) |> Rule
end

function distrib_right(outop, inop)
	@assert Base.isbinaryoperator(outop)
	@assert Base.isbinaryoperator(inop)
	:( ($outop)(($inop)(a,b), c) == ($inop)(($outop)(a,c),($outop)(b,c)) ) |> Rule
end

function monoid(op, id)
	let id = ~id
		@assert Base.isbinaryoperator(op)
		[associativity(op), identity_left(op, id), identity_right(op,id)]
	end
end
macro monoid(op, id) monoid(op, id) end


function commutative_monoid(op, id)
	let id = ~id;
		@assert Base.isbinaryoperator(op)
		[commutativity(op), associativity(op), identity_left(op, id)]
	end
end
macro commutative_monoid(op, id) commutative_monoid(op, id) end

# constructs a semantic theory about a an abelian group
# The definition of a group does not require that a ⋅ b = b ⋅ a
# for all elements a and b in G. If this additional condition holds,
# then the operation is said to be commutative, and the group is called an abelian group.
function commutative_group(op, id, invop)
	let id = ~id;
		@assert Base.isbinaryoperator(op)
		# @assert Base.isunaryoperator(invop)
		commutative_monoid(op, id) ∪ [inverse_right(op, id, invop)]
	end
end
abelian_group(op, id, invop) = commutative_group(op, id, invop)
macro commutative_group(op, id, invop) commutative_group(op, id, invop) end
macro abelian_group(op, id, invop) commutative_group(op, id, invop) end




distrib(outop, inop) = [
	distrib_left(outop, inop), distrib_right(outop, inop),
]
