commutativity(op) = :( ($op)(~a, ~b) == ($op)(~b, ~a) ) |> Rule
right_associative(op) = :( ($op)(~a, $(op)(~b,~c)) → ($op)($(op)(~a,~b), ~c) ) |> Rule
left_associative(op) = :( ($op)($(op)(~a,~b), c) → ($op)(~a, $(op)(~b,~c)) ) |> Rule

associativity_left(op) = :( ($op)(~a, $(op)(~b,~c)) → ($op)($(op)(~a,~b), ~c) ) |> Rule
associativity_right(op) = :(  ($op)($(op)(~a,~b), ~c) → ($op)(~a, $(op)(~b,~c)) ) |> Rule

associativity(op) = [associativity_left(op), associativity_right(op)]

identity_left(op, id) = :( ($op)($id, ~a) → ~a ) |> Rule 
identity_right(op, id) = :( ($op)(~a, $id) → ~a ) |> Rule 

inverse_left(op, id, invop) = :( ($op)(($invop)(~a), ~a) → $id ) |> Rule
inverse_right(op, id, invop) = :( ($op)(~a, ($invop)(~a)) → $id ) |> Rule

# distributivity of two operations
# example: `@distrib (⋅) (⊕)`
function distrib_left(outop, inop)
	# @assert Base.isbinaryoperator(outop)
	# @assert Base.isbinaryoperator(inop)
	:( ($outop)(~a, ($inop)(~b,~c)) == ($inop)(($outop)(~a,~b),($outop)(~a,~c)) ) |> Rule
end

function distrib_right(outop, inop)
	# @assert Base.isbinaryoperator(outop)
	# @assert Base.isbinaryoperator(inop)
	:( ($outop)(($inop)(~a,~b), ~c) == ($inop)(($outop)(~a,~c),($outop)(~b,~c)) ) |> Rule
end

function monoid(op, id)
		# @assert Base.isbinaryoperator(op)
	[associativity_left(op), associativity_right(op),
	identity_left(op, id), identity_right(op,id)]
end
macro monoid(op, id) monoid(op, id) end


function commutative_monoid(op, id)
	# @assert Base.isbinaryoperator(op) # Why this restriction?
	[commutativity(op), associativity_left(op),
	associativity_right(op), identity_left(op, id)]
end
macro commutative_monoid(op, id) commutative_monoid(op, id) end

# constructs a semantic theory about a an abelian group
# The definition of a group does not require that a ⋅ b = b ⋅ a
# for all elements a and b in G. If this additional condition holds,
# then the operation is said to be commutative, and the group is called an abelian group.
function commutative_group(op, id, invop)
	# @assert Base.isbinaryoperator(op)
	# @assert Base.isunaryoperator(invop)
	commutative_monoid(op, id) ∪ [inverse_right(op, id, invop)]
end

distrib(outop, inop) = [
	distrib_left(outop, inop), distrib_right(outop, inop),
]
