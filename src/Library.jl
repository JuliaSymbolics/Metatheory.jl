# constructs a semantic theory about a commutative monoid
# A monoid whose operation is commutative is called a
# commutative monoid (or, less commonly, an abelian monoid).

include("docstrings.jl")

"""
    Library

Macros that generate common algebraic rewrite theories.
"""
module Library

using Metatheory.Patterns
using Metatheory.Rules


"""
    @commutativity op

Create a rule rewriting `op(a, b)` to `op(b, a)`.
"""
macro commutativity(op)
  RewriteRule(PatTerm(:call, op, [PatVar(:a), PatVar(:b)]), PatTerm(:call, op, [PatVar(:b), PatVar(:a)]))
end

"""
    @right_associative op

Create a rule rewriting `op(a, op(b, c))` to `op(op(a, b), c)`.
"""
macro right_associative(op)
  RewriteRule(
    PatTerm(:call, op, [PatVar(:a), PatTerm(:call, op, [PatVar(:b), PatVar(:c)])]),
    PatTerm(:call, op, [PatTerm(:call, op, [PatVar(:a), PatVar(:b)]), PatVar(:c)]),
  )
end
"""
    @left_associative op

Create a rule rewriting `op(op(a, b), c)` to `op(a, op(b, c))`.
"""
macro left_associative(op)
  RewriteRule(
    PatTerm(:call, op, [PatTerm(:call, op, [PatVar(:a), PatVar(:b)]), PatVar(:c)]),
    PatTerm(:call, op, [PatVar(:a), PatTerm(:call, op, [PatVar(:b), PatVar(:c)])]),
  )
end


"""
    @identity_left op id

Create a rule rewriting `op(id, a)` to `a`.
"""
macro identity_left(op, id)
  RewriteRule(PatTerm(:call, op, [id, PatVar(:a)]), PatVar(:a))
end

"""
    @identity_right op id

Create a rule rewriting `op(a, id)` to `a`.
"""
macro identity_right(op, id)
  RewriteRule(PatTerm(:call, op, [PatVar(:a), id]), PatVar(:a))
end

"""
    @inverse_left op id invop

Create a rule rewriting `op(invop(a), a)` to `id`.
"""
macro inverse_left(op, id, invop)
  RewriteRule(PatTerm(:call, op, [PatTerm(:call, invop, [PatVar(:a)]), PatVar(:a)]), id)
end
"""
    @inverse_right op id invop

Create a rule rewriting `op(a, invop(a))` to `id`.
"""
macro inverse_right(op, id, invop)
  RewriteRule(PatTerm(:call, op, [PatVar(:a), PatTerm(:call, invop, [PatVar(:a)])]), id)
end


"""
    @associativity op

Return both left- and right-associativity rules for `op`.
"""
macro associativity(op)
  esc(quote
    [(@left_associative $op), (@right_associative $op)]
  end)
end

"""
    @monoid op id

Return associativity and identity rules for a monoid operation.
"""
macro monoid(op, id)
  esc(quote
    [(@left_associative($op)), (@right_associative($op)), (@identity_left($op, $id)), (@identity_right($op, $id))]
  end)
end

"""
    @commutative_monoid op id

Return commutativity, associativity, and identity rules for a commutative
monoid operation.
"""
macro commutative_monoid(op, id)
  esc(quote
    [(@commutativity $op), (@left_associative $op), (@right_associative $op), (@identity_left $op $id)]
  end)
end

# constructs a semantic theory about a an abelian group
# The definition of a group does not require that a ⋅ b = b ⋅ a
# for all elements a and b in G. If this additional condition holds,
# then the operation is said to be commutative, and the group is called an abelian group.
"""
    @commutative_group op id invop

Return a commutative-monoid theory together with an inverse rule.
"""
macro commutative_group(op, id, invop)
  # @assert Base.isbinaryoperator(op)
  # @assert Base.isunaryoperator(invop)
  esc(quote
    (@commutative_monoid $op $id) ∪ [@inverse_right $op $id $invop]
  end)
end

"""
    @distrib outop inop

Return left- and right-distributivity rules for `outop` over `inop`.
"""
macro distrib(outop, inop)
  esc(quote
    [(@distrib_left $outop $inop), (@distrib_right $outop $inop)]
  end)
end



# distributivity of two operations
# example: `@distrib (⋅) (⊕)`
"""
    @distrib_left outop inop

Create the left-distributivity rule for `outop` over `inop`.
"""
macro distrib_left(outop, inop)
  esc(quote
    @rule a b c ($outop)(a, $(inop)(b, c)) == $(inop)($(outop)(a, b), $(outop)(a, c))
  end)
end

"""
    @distrib_right outop inop

Create the right-distributivity rule for `outop` over `inop`.
"""
macro distrib_right(outop, inop)
  esc(quote
    @rule a b c ($outop)($(inop)(a, b), c) == $(inop)($(outop)(a, c), $(outop)(b, c))
  end)
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
export @left_associative
export @right_associative
export @inverse_left
export @inverse_right

end
