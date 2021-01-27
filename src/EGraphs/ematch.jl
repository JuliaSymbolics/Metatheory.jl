include("../rule.jl")
include("../util.jl")
include("egg.jl")

# https://www.philipzucker.com/egraph-2/
# https://github.com/philzook58/EGraphs.jl/blob/main/src/matcher.jl
# https://www.hpl.hp.com/techreports/2003/HPL-2003-148.pdf
# TODO support destructuring and type assertions

function ematchlist(e::EGraph, t::Vector{Any}, v::Vector{Int64}, sub)
    Channel() do c
        if length(t) != length(v) || length(t) == 0 || length(v) == 0
            put!(c, sub)
        else
            for sub1 in ematch(e, t[1], v[1], sub)
                for sub2 in ematchlist(e, t[2:end], v[2:end], sub1)
                    put!(c, sub2)
                end
            end
        end
    end
end

# sub should be a map from pattern variables to Id
function ematch(e::EGraph, t::Symbol, v::Int64, sub)
    Channel() do c
        if haskey(sub, t)
            find(e, sub[t]) == find(e, v) ? put!(c, sub) : pass
        else
            # TODO put type assertions here???
            put!(c,  Base.ImmutableDict(sub, t => EClass(find(e, v))))
        end
    end
end

ematch(e::EGraph, t, v::Int64, sub) = Channel() do c sub end

function ematch(e::EGraph, t::Expr, v::Int64, sub)
    Channel() do c
        for n in e.M[find(e,v)]
            (!(n isa Expr) || n.head != t.head) && continue
            start = 1
            if n.head == :call
                n.args[1] != t.args[1] && continue
                start = 2
            end
            for sub1 in ematchlist(e, t.args[start:end], n.args[start:end] .|> x -> x.id, sub)
                put!(c,sub1)
            end

        end
    end
end


inst(var, G::EGraph, sub) = haskey(sub, var) ? sub[var] : add!(G, var)

inst(p::Expr, G::EGraph, sub) = add!(G, p)

instantiate(G::EGraph, p, sub) = df_walk(inst, p, G, sub; skip_call=true)

function eqsat_step!(G::EGraph, theory::Vector{Rule})
    matches = []
    EMPTY_DICT2 = Base.ImmutableDict{Symbol, EClass}()

    # read only phase
    for rule ∈ theory
        for (id, cls) ∈ G.M
            for sub in ematch(G, rule.left, id, EMPTY_DICT2)
                display(sub); println()
                !isempty(sub) && push!(matches, (rule, sub, id))
            end
        end
    end

    for (rule, sub, id) ∈ matches
        println("rule ", rule, " matched on ", id)
        l = instantiate(G,rule.left,sub)
        r = instantiate(G,rule.right,sub)
        merge!(G,l.id,r.id)
    end

    # display(G.parents); println()
    # display(G.M); println()

    rebuild!(G)

    return G
end

r = @rule foo(x,y) => 2*x%y
G = EGraph(:(foo(b,c)))

G = eqsat_step!(G, [r])
display(G.M)

# OK

equality_saturation!(G::EGraph, theory::Vector{Rule}) =
    normalize(eqsat_step!, G, theory)

comm_monoid = @theory begin
    a * 0 => a
    a * b => b * a
    a * (b * c) => (a * b) * c
end

G = EGraph(:(zoo * (foo * 0)))

equality_saturation!(G, comm_monoid)

display(G.M)

display(G.root)
