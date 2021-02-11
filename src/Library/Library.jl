# constructs a semantic theory about a commutative monoid
# A monoid whose operation is commutative is called a
# commutative monoid (or, less commonly, an abelian monoid).
# TODO test

# TODO split everything up. Use auto ACD compiler for matchcore backend
macro commutative_monoid(t, op, id, func)
	zop = Meta.quot(op)
   quote
	   @theory begin
			($op)($id, a) => a
			($op)(a, $id) => a
			# closure
			($op)(a::$t, b::$t) |> ($func)(a,b)
			# associativity reductions implying commutativity
			($op)(a::$t, ($op)(b::$t, c)) |>
				(z = ($func)(a, b); Expr(:call, ($zop), z, c))

			($op)(($op)(a::$t, c), b::$t) |>
				(z = ($func)(a, b); Expr(:call, ($zop), z, c))

			($op)(a::$t, ($op)(c, b::$t)) |>
				(z = ($func)(a, b); Expr(:call, ($zop), z, c))

			($op)(($op)(c, a::$t), b::$t) |>
				(z = ($func)(a, b); Expr(:call, ($zop), z, c))
	   end
   end
end


# constructs a semantic theory about a an abelian group
# The definition of a group does not require that a ⋅ b = b ⋅ a
# for all elements a and b in G. If this additional condition holds,
# then the operation is said to be commutative, and the group is called an abelian group.
# TODO test
macro abelian_group(t, op, id, invop, func)
	zop = Meta.quot(op)
   quote
	   @theory begin
			# identity element
			($op)($id, a) => a
			($op)(a, $id) => a
			# inversibility
			($op)(a, ($invop)(a)) => $id
			($op)(($invop)(a), a) => $id
			# closure
			($op)(a::$t, b::$t) |> ($func)(a,b)
			# inverse
			# associativity reductions
			($op)(a::$t, ($op)(b::$t, c)) |> (z = ($func)(a, b); Expr(:call, ($zop), z, c))
			($op)(($op)(a::$t, c), b::$t) |> (z = ($func)(a, b); Expr(:call, ($zop), z, c))
			($op)(a::$t, ($op)(c, b::$t)) |> (z = ($func)(a, b); Expr(:call, ($zop), z, c))
			($op)(($op)(c, a::$t), b::$t) |> (z = ($func)(a, b); Expr(:call, ($zop), z, c))
	   end
   end
end


# distributivity of two operations
# example: `@distrib (⋅) (⊕)`
macro distrib(outop, inop)
	@assert Base.isbinaryoperator(outop)
	@assert Base.isbinaryoperator(inop)
	quote
		@theory begin
			($outop)(a, ($inop)(b,c)) => ($inop)(($outop)(a,b),($outop)(a,c))
			($outop)(($inop)(a,b), c) => ($inop)(($outop)(a,c),($outop)(b,c))
		end
	end
end
