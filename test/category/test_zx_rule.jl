include("test_zx.jl")

h_cancel = @theory begin
    H() ⋅ H() => I()
end

id_rule = @theory begin
    Z(θ) |> begin
        c = addexpr!(_egraph, _lhs_expr)
        analyze!(_egraph, Main.ZXAnalysis)
        md = getdata(c, Main.ZXAnalysis)
        if md.ninput == md.noutput == 1 && getdata(θ, Main.ZXAnalysis) == 0
            return Main.id(1)
        else
            return _lhs_expr
        end
    end
    X(θ) |> begin
        c = addexpr!(_egraph, _lhs_expr)
        analyze!(_egraph, Main.ZXAnalysis)
        md = getdata(c, Main.ZXAnalysis)
        if md.ninput == md.noutput == 1 && getdata(θ, Main.ZXAnalysis) == 0
            return Main.id(1)
        else
            return _lhs_expr
        end
    end
end

id_otimes_compose = @theory begin
    I() ⊗ I() |> begin
        c = addexpr!(_egraph, _lhs_expr)
        analyze!(_egraph, Main.ZXAnalysis)
        md = getdata(c, Main.ZXAnalysis)
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

function EGraphs.instantiateterm(g::EGraph, pat::PatTerm,  T::Type{ZXTerm{I, O}}, sub::Sub, rule::Rule) where {I, O}
    T(map(x -> EGraphs.instantiate(g, x, sub, rule), pat.args)...)
end

t = otimes(compose(h, h), compose(zspider(1, 1, 0), xspider(1, 1, 0)))
G = EGraph(t)
saturate!(G, ZXRules)
t_ex = extract!(G, astsize)
@test t_ex == id(2)
