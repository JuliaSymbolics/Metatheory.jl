module TermInterface

using ..Util
using Base.Meta

# Interface for Expr. Implement these methods for your own type to
# Use it instead of Expr in egraphs!
gethead(e::Expr) = isexpr(e, :call) ? e.args[1] : e.head
getargs(e::Expr) = e.args[(isexpr(e, :call) ? 2 : 1):end]
istree(e::Expr) = true
getmetadata(e::Expr) = (iscall=isexpr(e, :call),)
preprocess(e::Expr) = cleanast(e)

# Fallback implementation for all other types
gethead(e) = e
getargs(e) = []
istree(a) = false
getmetadata(e) = nothing
preprocess(e) = e

export gethead
export getargs
export istree
export getmetadata
export preprocess
end
