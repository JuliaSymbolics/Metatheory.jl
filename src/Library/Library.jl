# constructs a semantic theory about a commutative monoid
# A monoid whose operation is commutative is called a
# commutative monoid (or, less commonly, an abelian monoid).

include("../docstrings.jl")

module Library

# TODO compile for Matchcore backend
@info "NOTE: The current implementation of the Metatheory library currently works
correctly only with the EGraphs backend."

include("algebra.jl")

using ..Metatheory
# include("../util.jl")
# include("../rule.jl")

# theory generation macros
export commutativity
export associativity
export identity_left
export identity_right
export distrib_left
export distrib_right
export distrib
export monoid
export commutative_monoid
export commutative_group
export abelian_group
export @commutative_monoid
export @commutative_group
export @abelian_group

end
