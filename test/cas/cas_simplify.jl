using Metatheory
using Metatheory.Library
using Metatheory.EGraphs
using Metatheory.Classic
using Metatheory.Util
using Metatheory.EGraphs.Schedulers
using Metatheory.TermInterface

function customlt(x,y)
    if typeof(x) == Expr && typeof(y) == Expr 
        false
    elseif typeof(x) == typeof(y)
        isless(x,y)
    elseif x isa Symbol && y isa Number
        false
    elseif x isa Expr && y isa Number
        false
    elseif x isa Expr && y isa Symbol
        false 
    else true end
end

canonical_t = @theory begin
    # restore n-arity
    (x * x)             => x^2
    (x^n::Number * x)   => x^(n+1)
    (x * x^n::Number)   => x^(n+1) 
    (x + (+)(ys...)) => +(x,ys...)
    ((+)(xs...) + y) => +(xs..., y)
    (x * (*)(ys...)) => *(x,ys...)
    ((*)(xs...) * y) => *(xs..., y)

    (*)(xs...)      |> Expr(:call, :*, sort!(xs; lt=customlt)...)
    (+)(xs...)      |> Expr(:call, :+, sort!(xs; lt=customlt)...)
end

# Metatheory.options[:verbose] = true
# Metatheory.options[:printiter] = true



function simplcost(n::ENode, g::EGraph, an::Type{<:AbstractAnalysis})
    cost = 0 + arity(n)
    if n.head == :∂
        cost += 20
    end
    for id ∈ n.args
        eclass = geteclass(g, id)
        !hasdata(eclass, an) && (cost += Inf; break)
        cost += last(getdata(eclass, an))
    end
    return cost
end

function simplify(ex; steps=4)
    params = SaturationParams(
        scheduler=ScoredScheduler,
        eclasslimit=5000,
        timeout=7,
        schedulerparams=(1000,5, Schedulers.exprsize),
        #stopwhen=stopwhen,
    )
    hist = UInt64[]
    push!(hist, hash(ex))
    for i ∈ 1:steps
        g = EGraph(ex)
        saturate!(g, cas, params; mod=@__MODULE__)
        ex = extract!(g, simplcost)
        ex = rewrite(ex, canonical_t; clean=false, m=@__MODULE__)
        if !TermInterface.istree(typeof(ex))
            return ex
        end
        if hash(ex) ∈ hist
            println("loop detected $ex")
            return ex
        end
        println(ex)
        push!(hist, hash(ex))
    end
    # println(res)
    # for (id, ec) ∈ g.classes
    #     println(id, " => ", collect(ec.nodes))
    #     println("\t\t", getdata(ec, ExtractionAnalysis{astsize}))
    # end
    
end
macro simplify(ex)
    Meta.quot(simplify(ex))
end