"""
This module contains function definitions
for using custom types as Terms.
"""
module TermInterface

using ..Util
using Base.Meta

# TODO document this interface for extending for custom types
# Interface for Expr. Implement these methods for your own type to
# Use it instead of Expr in egraphs!
# gethead(e::Expr) = isexpr(e, :call) ? e.args[1] : e.head
gethead(e::Expr) = e.head
getargs(e::Expr) = e.args
istree(e::Type{Expr}) = true
getmetadata(e::Expr) = nothing
arity(e::Expr) = length(getargs(e)) # optional
preprocess(e::Expr) = cleanast(e)
similarterm(x::Type{Expr}, head, args; metadata=nothing) = Expr(head, args...)


# Fallback implementation for all other types
istree(t::Type) = false
getmetadata(e) = nothing
arity(e) = 0 # optional
preprocess(e) = e
function similarterm(x::Type{T}, head::T, args; metadata=nothing) where T
    if !istree(T) head else head(args...) end
end 

export gethead
export getargs
export istree
export getmetadata
export preprocess
export arity
export similarterm
end
