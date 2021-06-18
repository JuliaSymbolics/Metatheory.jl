using SymbolicUtils
using Metatheory
using Metatheory.EGraphs
using TermInterface
using Test 

import SymbolicUtils: Symbolic, Sym, operation, arguments, Term

# FIXME
# TermInterface.isterm(t::Type{<:Symbolic}) = SymbolicUtils.isterm(t)
TermInterface.isterm(t::Type{<:Sym}) = false
TermInterface.isterm(t::Type{<:Symbolic}) = true

TermInterface.gethead(t::Symbolic) = :call 
TermInterface.gethead(t::Sym) = t
TermInterface.getargs(t::Symbolic) = [operation(t), arguments(t)...]
TermInterface.arity(t::Symbolic) = length(arguments(t))

function unflatten_args(f, args, N=4)
    length(args) < N && return Term{Real}(f, args)
    unflatten_args(f, [Term{Real}(f, group)
                                       for group in Iterators.partition(args, N)], N)
end

function EGraphs.preprocess(t::Symbolic)
    # TODO change to isterm after PR
    if SymbolicUtils.istree(t)
        f = operation(t)
        if f == (+) || f == (*) || f == (-) # check out for other binary ops TODO
            a = arguments(t)
            if length(a) > 2
                return unflatten_args(f, a, 2)
            end
        end
    end
    return t
end

function TermInterface.similarterm(x::Type{<:Symbolic{T}}, head, args; metadata=nothing) where T
    @assert head == :call
    Term{T}(args[1], args[2:end])
end


function costfun(n::ENode, g::EGraph, an)
    if arity(n) == 0
        if n.head == :+
            return 1
        elseif n.head == :-
            return 1
        elseif n.head == :*
            return 3
        elseif n.head == :/
            return 30
        else
            return 1
        end
    end
    if !(n.head == :call)
        return 1000000000
    end
    cost = 0

    for id ∈ n.args
        eclass = geteclass(g, id)
        !hasdata(eclass, an) && (cost += Inf; break)
        cost += last(getdata(eclass, an))
    end
    cost
end


@metatheory_init ()


theory = @methodtheory begin
    a * x == x * a
    a * x + a * y == a*(x+y)
end

import SymbolicUtils.symtype
function optimize(ex)
    g = EGraph()

    settermtype!(g, Term{symtype(ex), Any})

    ec, _ = addexpr!(g, ex)

    g.root = ec.id

    @show g.root
    display(g.classes); println()

    # (2x) * x => 2 * (x * x) => 2x^2


    params = SaturationParams()
    saturate!(g, theory, params)

    extract!(g, costfun) # --> "term" head args
end


@syms a b
2(a+b) - a*(a+b)

optimize(2a + 2b - (a*(a + b)))

