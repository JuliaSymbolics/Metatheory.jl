include("../rule.jl")
include("../theory.jl")
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
                # display(sub); println()
                !isempty(sub) && push!(matches, (rule, sub, id))
            end
        end
    end

    for (rule, sub, id) ∈ matches
        # println("rule ", rule, " matched on ", id)
        l = instantiate(G,rule.left,sub)
        r = instantiate(G,rule.right,sub)
        merge!(G,l.id,r.id)
    end

    # display(G.parents); println()
    # display(G.M); println()
    saturated = isempty(G.dirty)

    rebuild!(G)

    return saturated, G
end

# TODO plot how egraph shrinks and grows during saturation
function equality_saturation!(G::EGraph, theory::Vector{Rule}; timeout=3000)
    curr_iter = 0
    while true
        @info curr_iter
        curr_iter+=1
        saturated, G = eqsat_step!(G, theory)

        saturated && (@info "E-GRAPH SATURATED"; break)
        saturated && (@info "E-GRAPH TIMEOUT"; break)
    end
    return G
end


r = @rule foo(x,y) => 2*x%y
G = EGraph(:(foo(b,c)))

saturate!(G, [r])

G.M |> display

# OK


comm_monoid = @theory begin
    a * 1 => a
    a * b => b * a
    a * (b * c) => (a * b) * c
end

G = EGraph(binarize!(:((boo * 1 * 1 * 1 * 1 * 1 * zoo * 1 * 1 * foo * 1)), :*))
@time saturate!(G, comm_monoid)
display(G.M)
G.U |> length
G.M |> length


## Simple Extraction

# computes the cost of a constant
astsize(G::EGraph, n) = 1.0

# computes the weight of a function call
function astsize(G::EGraph, n::Expr)
    @assert isenode(n)
    start = isexpr(n, :call) ? 2 : 1
    # if statements about the called function can go here
    length(e.args[start:end])
end

function getbest(G::EGraph, costs::Dict{Int64, Vector{Tuple{Any, Float64}}}, root::Int64)
    # computed costs of equivalent nodes, weighted sum
    ccosts =
    for n ∈ G.M[root]

    end
end

function extract(G::EGraph, cost::Function)
    costs = Dict{Int64, Vector{Float64}}()

    # compute costs with weights
    for (id, cls) ∈ G.M
        costs[id] = cls .|> cost
    end

    # extract best
    getbest(G, costs, root)
end
