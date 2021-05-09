using SymbolicUtils
using Metatheory
using Metatheory.EGraphs
import SymbolicUtils: Symbolic, Sym, operation, arguments, Term

TermInterface.istree(t::Symbolic) = SymbolicUtils.istree(t)
TermInterface.gethead(t::Symbolic) = :call 
TermInterface.gethead(t::Sym) = t
TermInterface.getargs(t::Symbolic) = [operation(t), arguments(t)...]
TermInterface.arity(t::Symbolic) = length(arguments(t))

function unflatten_args(f, args, N=4)
    length(args) < N && return Term{Real}(f, args)
    unflatten_args(f, [Term{Real}(f, group)
                                       for group in Iterators.partition(args, N)], N)
end

function TermInterface.preprocess(t::Symbolic)
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

function EGraphs.instantiateterm(g::EGraph, pat::PatTerm, x::Type{<:Symbolic{T}}, children) where {T}
    @assert pat.head == :call
    return Term{T}(children[1], children[2:end])
end


# Define an extraction method dispatching on MyExpr
function EGraphs.extractnode(g::EGraph, n::ENode{<:Symbolic{T}}, extractor::Function) where {T}
    # extracted arguments
    ret_args = [extractor(a) for a in n.args]
    if n.head == :call 
        return Term{T}(ret_args[1], ret_args[2:end])
    end
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

    ec = addexpr!(g, ex)

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


using Metatheory.TermInterface
