using Base.Meta

iscall(e) = false
iscall(e::Expr) = isexpr(e, :call)

getfunsym(e::Expr) = iscall(e) ? e.args[1] : e.head
getfunsym(e) = e

setfunsym!(e::Expr, s) = iscall(e) ? (e.args[1] = s) : (e.head = s)
setfunsym!(e, s) = s

getfunargs(e::Expr) = e.args[(iscall(e) ? 2 : 1):end]

getfunargs(e) = []

function setfunargs!(e::Expr, args::Vector)
    e.args[(iscall(e) ? 2 : 1):end] = args
end
setfunargs!(e, args) = []

istree(e::Expr) = true
istree(a) = false
