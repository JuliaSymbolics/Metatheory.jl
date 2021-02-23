using Base.Meta

iscall(e) = false
iscall(e::Expr) = isexpr(e, :call)

get_funsym(e::Expr) = isexpr(e, :call) ? e.args[1] : e.head
get_funsym(e) = e

get_funarg(e::Expr) = let start = (isexpr(e, :call) ? 2 : 1)
    e.args[start:end]
end
get_funarg(e) = []

set_funarg(e::Expr, args::Vector{Any}) = let start = (isexpr(e, :call) ? 2 : 1)
    e.args[start:end] = args
end
set_funarg(e) = []
