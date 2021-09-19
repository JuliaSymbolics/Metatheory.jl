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
