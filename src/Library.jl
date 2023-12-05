# constructs a semantic theory about a commutative monoid
# A monoid whose operation is commutative is called a
# commutative monoid (or, less commonly, an abelian monoid).

include("docstrings.jl")

module Library

using Metatheory.Patterns
using Metatheory.Rules


macro commutativity(op)
  RewriteRule(PatTerm(PatHead(:call), op, PatVar(:a), PatVar(:b)), PatTerm(PatHead(:call), op, PatVar(:b), PatVar(:a)))
end

macro right_associative(op)
  RewriteRule(
    PatTerm(PatHead(:call), op, PatVar(:a), PatTerm(PatHead(:call), op, PatVar(:b), PatVar(:c))),
    PatTerm(PatHead(:call), op, PatTerm(PatHead(:call), op, PatVar(:a), PatVar(:b)), PatVar(:c)),
  )
end
macro left_associative(op)
  RewriteRule(
    PatTerm(PatHead(:call), op, PatTerm(PatHead(:call), op, PatVar(:a), PatVar(:b)), PatVar(:c)),
    PatTerm(PatHead(:call), op, PatVar(:a), PatTerm(PatHead(:call), op, PatVar(:b), PatVar(:c))),
  )
end


macro identity_left(op, id)
  RewriteRule(PatTerm(PatHead(:call), op, id, PatVar(:a)), PatVar(:a))
end

macro identity_right(op, id)
  RewriteRule(PatTerm(PatHead(:call), op, PatVar(:a), id), PatVar(:a))
end

macro inverse_left(op, id, invop)
  RewriteRule(PatTerm(PatHead(:call), op, PatTerm(PatHead(:call), invop, PatVar(:a)), PatVar(:a)), id)
end
macro inverse_right(op, id, invop)
  RewriteRule(PatTerm(PatHead(:call), op, PatVar(:a), PatTerm(PatHead(:call), invop, PatVar(:a))), id)
end


macro associativity(op)
  esc(quote
    [(@left_associative $op), (@right_associative $op)]
  end)
end

macro monoid(op, id)
  esc(quote
    [(@left_associative($op)), (@right_associative($op)), (@identity_left($op, $id)), (@identity_right($op, $id))]
  end)
end

macro commutative_monoid(op, id)
  esc(quote
    [(@commutativity $op), (@left_associative $op), (@right_associative $op), (@identity_left $op $id)]
  end)
end

# constructs a semantic theory about a an abelian group
# The definition of a group does not require that a ⋅ b = b ⋅ a
# for all elements a and b in G. If this additional condition holds,
# then the operation is said to be commutative, and the group is called an abelian group.
macro commutative_group(op, id, invop)
  # @assert Base.isbinaryoperator(op)
  # @assert Base.isunaryoperator(invop)
  esc(quote
    (@commutative_monoid $op $id) ∪ [@inverse_right $op $id $invop]
  end)
end

macro distrib(outop, inop)
  esc(quote
    [(@distrib_left $outop $inop), (@distrib_right $outop $inop)]
  end)
end



# distributivity of two operations
# example: `@distrib (⋅) (⊕)`
macro distrib_left(outop, inop)
  esc(quote
    @rule a b c ($outop)(a, $(inop)(b, c)) == $(inop)($(outop)(a, b), $(outop)(a, c))
  end)
end

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
