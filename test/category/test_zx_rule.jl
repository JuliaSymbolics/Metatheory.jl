include("test_zx.jl")

h_cancel = @theory begin
    H() ⋅ H() => I()
end

id_rule = @theory begin
    Z(θ) |> begin
        md = getdata(_lhs_expr, Main.ZXAnalysis)
        if md.ninput == md.noutput == 1 && getdata(θ, Main.ZXAnalysis) == 0
            return Main.id(1)
        else
            return _lhs_expr
        end
    end
    X(θ) |> begin
        md = getdata(_lhs_expr, Main.ZXAnalysis)
        if md.ninput == md.noutput == 1 && getdata(θ, Main.ZXAnalysis) == 0
            return Main.id(1)
        else
            return _lhs_expr
        end
    end
end

id_otimes_compose = @theory begin
    I() ⊗ I() |> begin
        md = getdata(_lhs_expr, Main.ZXAnalysis)
        @assert md.ninput == md.noutput
        return Main.id(md.ninput)
    end
    I() ⋅ f => f
    f ⋅ I() => f
end

ZXRules = h_cancel ∪ id_rule ∪ id_otimes_compose

function EGraphs.extractnode(n::ENode{T}, extractor::Function) where {T <: ZXTerm}
    args = []
    @assert n.head == :call
    I = ninput(T)
    O = noutput(T)
    for i in 2:length(n.args)
        push!(args, extractor(n.args[i]))
    end

    return ZXTerm{I, O}(extractor(n.args[1]), args)
end

function EGraphs.instantiateterm(g::EGraph, pat::PatTerm, T::Type{ZXTerm{I, O}}, children) where {I, O}
    T(children...)
end

t = otimes(compose(h, h), compose(zspider(1, 1, 0), xspider(1, 1, 0)))
G = EGraph(t)
analyze!(G, ZXAnalysis)
saturate!(G, ZXRules, mod=@__MODULE__)
t_ex = extract!(G, astsize)
@test t_ex == id(2)
