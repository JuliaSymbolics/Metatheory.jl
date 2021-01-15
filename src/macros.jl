# constructs a semantic theory about a monoid
# TODO test
macro monoid(t, op, id, func)
	zop = Meta.quot(op)
   quote
	   @theory begin
			($op)($id, a) => a
			($op)(a, $id) => a
			# closure
			($op)(a::$t, b::$t) ↦ ($func)(a,b)
			# associativity reductions
			($op)(a::$t, ($op)(b::$t, c)) ↦ (z = ($func)(a, b); Expr(:call, ($zop), z, c))
			($op)(($op)(a::$t, c), b::$t) ↦ (z = ($func)(a, b); Expr(:call, ($zop), z, c))
			($op)(a::$t, ($op)(c, b::$t)) ↦ (z = ($func)(a, b); Expr(:call, ($zop), z, c))
			($op)(($op)(c, a::$t), b::$t) ↦ (z = ($func)(a, b); Expr(:call, ($zop), z, c))
	   end
   end
end

# distributivity of two operations
# example: `@distrib (⋅) (⊕)`
# TODO test
macro distrib(outop, inop)
	@assert Base.isbinaryoperator(outop)
	@assert Base.isbinaryoperator(inop)
	quote
		@theory begin
			($outop)(a, ($inop)(b,c)) => ($inop)(($outop)(a,b),($outop)(a,c))
			($outop)(($inop)(a,b), c) => ($inop)(($outop)(a,b),($outop)(b,c))
		end
	end
end
