macro commutativity(op) 
	RewriteRule(
		PatTerm(:call, op, [PatVar(:a), PatVar(:b)]), 
		PatTerm(:call, op, [PatVar(:b), PatVar(:a)]))
end 

macro right_associative(op)
	RewriteRule(
		PatTerm(:call, op, [PatVar(:a), 
			PatTerm(:call, op, [PatVar(:b), PatVar(:c)])]),
		PatTerm(:call, op, [
			PatTerm(:call, op, [PatVar(:a), PatVar(:b)]), 
			PatVar(:c), 
			]))
end
macro left_associative(op) 
	RewriteRule(
		PatTerm(:call, op, [
			PatTerm(:call, op, [PatVar(:a), PatVar(:b)]), 
			PatVar(:c), 
			]),
		PatTerm(:call, op, [PatVar(:a), 
			PatTerm(:call, op, [PatVar(:b), PatVar(:c)])]))
end


macro identity_left(op, id) 
	RewriteRule(PatTerm(:call, op, [id, PatVar(:a)]), PatVar(:a))
end

macro identity_right(op, id) 
	RewriteRule(PatTerm(:call, op, [PatVar(:a), id]), PatVar(:a))
end

macro inverse_left(op, id, invop) 
	RewriteRule(PatTerm(:call, op, [
		PatTerm(:call, invop, [PatVar(:a)]), PatVar(:a)]), id) 
end
macro inverse_right(op, id, invop) 
	RewriteRule(PatTerm(:call, op, [
		PatVar(:a),
		PatTerm(:call, invop, [PatVar(:a)])]), id)
end


# distributivity of two operations
# example: `@distrib (⋅) (⊕)`
macro distrib_left(outop, inop)
	EqualityRule(
		# left 
		PatTerm(:call, outop, [
			PatVar(:a),
			PatTerm(:call, inop, [PatVar(:b), PatVar(:c)])
		]), 
		# right 
		PatTerm(:call, inop, [
			PatTerm(:call, outop, [PatVar(:a), PatVar(:b)]),
			PatTerm(:call, outop, [PatVar(:a), PatVar(:c)]),
		]))

end

macro distrib_right(outop, inop)
	EqualityRule(
		# left 
		PatTerm(:call, outop, [
			PatTerm(:call, inop, [PatVar(:a), PatVar(:b)]),
			PatVar(:c)
		]), 
		# right 
		PatTerm(:call, inop, [
			PatTerm(:call, outop, [PatVar(:a), PatVar(:c)]),
			PatTerm(:call, outop, [PatVar(:b), PatVar(:c)]),
		]))
end
