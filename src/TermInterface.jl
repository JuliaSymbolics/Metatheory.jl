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
# getargs(e::Expr) = @view e.args[(isexpr(e, :call) ? 2 : 1):end]
getargs(e::Expr) = e.args
istree(e::Expr) = true
getmetadata(e::Expr) = nothing
metadatatype(e::Expr) = Nothing
arity(e::Expr) = length(getargs(e)) # optional
preprocess(e::Expr) = cleanast(e)

# Fallback implementation for all other types
gethead(e) = e
getargs(e) = []
istree(a) = false
getmetadata(e) = nothing
metadatatype(e) = Nothing
arity(e) = length(getargs(e)) # optional
preprocess(e) = e

export gethead
export getargs
export istree
export getmetadata
export metadatatype
export preprocess
export arity
end
