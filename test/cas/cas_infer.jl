using Metatheory
using Metatheory.Library
using Metatheory.EGraphs
using Metatheory.NewSyntax
using Metatheory.Util
using Metatheory.EGraphs.Schedulers
using TermInterface

@metatheory_init

abstract type TypeAnalysis <: AbstractAnalysis end

function EGraphs.make(an::Type{TypeAnalysis}, g::EGraph, n::ENodeTerm)
    Any
end

function EGraphs.make(an::Type{TypeAnalysis}, g::EGraph, n::ENodeLiteral)
    v = n.value
    if v == :im 
        typeof(im)
    else
        typeof(v)
    end
end

function EGraphs.make(an::Type{TypeAnalysis}, g::EGraph, n::ENodeTerm{Expr})
    if exprhead(n) != :call
        # println("$n is not a call")
        t = Any
        # println("analyzed type of $n is $t")
        return t
    end
    sym = operation(n)
    if !(sym isa Symbol)
        # println("head $sym is not a symbol")
        t = Any
        # println("analyzed type of $n is $t")
        return t
    end

    symval = getfield(@__MODULE__, sym)
    child_classes = map(x -> geteclass(g, x), arguments(n))
    child_types = Tuple(map(x -> getdata(x, an, Any), child_classes))

    # t = t_arr[1]
    t = Core.Compiler.return_type(symval, child_types)

    if t == Union{}
        throw(MethodError(symval, child_types))
    end
    # println("analyzed type of $n is $t")
    return t
end

EGraphs.join(an::Type{TypeAnalysis}, from, to) = typejoin(from, to)

EGraphs.islazy(x::Type{TypeAnalysis}) = true

function infer(e)
    g = EGraph(e)
    analyze!(g, TypeAnalysis)
    getdata(geteclass(g, g.root), TypeAnalysis)
end
