using Metatheory
using Metatheory.Rewriters
using Test
# using SymbolicUtils

array_theory = @theory x y f g M N begin
    #map(f,x)[n:m] = map(f,x[n:m]) # but does NOT commute with filter
    map(f,fill(x,N))            == fill(apply(f,x), N) # hmm
    # cumsum(fill(x,N))           == collect(x:x:(N*x))
    fill(x,N)[y]                --> x
    length(fill(x,N))           --> N
    reverse(reverse(x))         --> x
    sum(fill(x,N))              --> x * N
    map(f,reverse(x))           == reverse(map(f, x))
    filter(f,reverse(x))        == reverse(filter(f,x))
    reverse(fill(x,N))          == fill(x,N) 
    filter(f, fill(x,N))        == (if apply(f, x); fill(x,N) else fill(x,0) end)
    filter(f, filter(g, x))     == filter(fand(f,g), x) # using functional &&
    cat(fill(x,N),fill(x,M))    == fill(x,N + M)
    cat(map(f,x), map(f,y))     == map(f, cat(x,y))
    map(f, cat(x,y))            == cat(map(f,x), map(f,y)) 
    map(f,map(g,x))             == map(f ∘ g, x)
    reverse( cat(x,y) )         == cat(reverse(y), reverse(x))
    map(f,x)[y]                 == apply(f,x[y])
    apply(f ⋅ g, x)             == apply(f, apply(g, x))

    map(f, reduce(g, x))        == mapreduce(f, g, x)
    map(f, foldl(g, x))         == mapfoldl(f, g, x)
    map(f, foldr(g, x))         == mapfoldr(f, g, x)
end

normalize_theory = @theory x y f g begin 
    fand(f, g)  --> ((x) -> f(x) && g(x))
    apply(f, x) => Expr(:call, f, x)
end

fold_theory = @theory x y begin 
    x::Number * y::Number => x*y
    x::Number + y::Number => x+y
    x::Number / y::Number => x/y
    # etc...
end

function expr_replace(env)
    function _expr_replace()
    end
    return _expr_replace
end

# function inline_lambda(ex::Expr)
#     exprhead(ex) != :call && return ex
#     fun = operation(ex)
#     !(fun isa Expr) && return ex
#     exprhead(fun) != :(->) && return ex
    
#     f_arg = arguments(fun)[1]
#     !(f_arg isa Symbol) && return ex
#     f_body = arguments(fun)[2]

#     args = arguments(ex)
#     length(args) != 1 && return ex

#     args[1]
#     body = Metatheory.Syntax.rmlines(substitute(f_body, Dict(f_arg => args[1]); fold=false))
#     if exprhead(body) == :block && length(arguments(body)) == 1
#         return arguments(body)[1]
#     else 
#         return body
#     end
# end

# inline_lambda(x) = x

params = SaturationParams()

function stream_optimize(ex)
    g = EGraph(ex)
    rep = saturate!(g, array_theory, params)
    @info rep
    ex = extract!(g, astsize;) # TODO cost fun with asymptotic complexity
    ex = Fixpoint(Postwalk(Chain(vcat(normalize_theory, fold_theory))))(ex)
    return ex
end

build_fun(ex) = eval(:(()->$ex))


@testset "Stream Fusion" begin
    ex = :( map(x -> 7 * x, fill(3,4)))
    opt = stream_optimize(ex)
    @test opt == :(fill(((x-> 7x))(3), 4))

    ex = :( map(x -> 7 * x, fill(3,4) )[1])
    opt = stream_optimize(ex)
    @test opt == :((x->7x)(3))
end
