"""Definitions of various utility functions for metaprogramming"""
module Util

using Base.Meta
## AST manipulation utility functions

# useful shortcuts for nested macros
"""Add a dollar expression"""
dollar(v) = Expr(:$, v)
"Make a block expression from an array of exprs"
block(vs...) = Expr(:block, vs...)
"Add a & expression"
amp(v) = Expr(:&, v)

export dollar
export block
export amp

include("cleaning.jl")
export rmlines
export binarize
export cleanast

include("walks.jl")
export df_walk
export df_walk!
export bf_walk
export bf_walk!

include("fixpoint.jl")
export normalize
export normalize_nocycle


end
