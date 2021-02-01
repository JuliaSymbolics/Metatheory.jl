# https://www.philipzucker.com/egraph-2/
# https://github.com/philzook58/EGraphs.jl/blob/main/src/matcher.jl
# https://www.hpl.hp.com/techreports/2003/HPL-2003-148.pdf
# TODO support destructuring and type assertions

# TODO ematching seems to be faster without spawning tasks

function ematchlist(e::EGraph, t::Vector{Any}, v::Vector{Int64}, sub)
    # Channel(;spawn=true) do c
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
    # Channel(;spawn=true) do c
    Channel() do c
        if haskey(sub, t)
            find(e, sub[t]) == find(e, v) ? put!(c, sub) : nothing
        else
            # TODO put type assertions here???
            put!(c,  Base.ImmutableDict(sub, t => EClass(find(e, v))))
        end
    end
end

ematch(e::EGraph, t, v::Int64, sub) = [sub]

function ematch(e::EGraph, t::Expr, v::Int64, sub)
    # Channel(;spawn=true) do c
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
