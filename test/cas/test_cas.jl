using Test
include("cas_theory.jl")
include("cas_simplify.jl")

@test :(4a) == @simplify 2a + a + a
@test :(a * b * c) == @simplify a * c * b
@test :(2x) == @simplify 1 * x * 2
@test :((a * b)^2) == @simplify (a * b)^2
@test :((a * b)^6) == @simplify (a^2 * b^2)^3
@test :(a + b + d) == @simplify a + b + (0 * c) + d
@test :(a + b) == @simplify a + b + (c * 0) + d - d
@test :(a) == @simplify (a + d) - d
@test :(a + b + d) == @simplify a + b * c^0 + d
@test :(a * b * x^(d + y)) == @simplify a * x^y * b * x^d
@test :(a * b * x^74103) == @simplify a * x^(12 + 3) * b * x^(42^3)

@test 1 == @simplify (x + y)^(a * 0) / (y + x)^0
@test 2 == @simplify cos(x)^2 + 1 + sin(x)^2
@test 2 == @simplify cos(y)^2 + 1 + sin(y)^2
@test 2 == @simplify sin(y)^2 + cos(y)^2 + 1

@test :(y + sec(x)^2) == @simplify 1 + y + tan(x)^2
@test :(y + csc(x)^2) == @simplify 1 + y + cot(x)^2



# @simplify ∂(x^2, x)

@time @simplify ∂(x^(cos(x)), x)

@test :(2x^3) == @simplify x * ∂(x^2, x) * x

# @simplify ∂(y^3, y) * ∂(x^2 + 2, x) / y * x

# @simplify (6 * x * x * y)

# @simplify ∂(y^3, y) / y

# # ex = :( ∂(x^(cos(x)), x) )
# ex = :( (6 * x * x * y) )
# g = EGraph(ex)
# saturate!(g, cas)
# g.classes
# extract!(g, simplcost; root=g.root)

# params = SaturationParams(
#     scheduler=BackoffScheduler,
#     eclasslimit=5000,
#     timeout=7,
#     schedulerparams=(1000,5),
#     #stopwhen=stopwhen,
# )

# ex = :((x+y)^(a*0) / (y+x)^0)
# g = EGraph(ex)
# @profview println(saturate!(g, cas, params))

# ex = extract!(g, simplcost)
# ex = rewrite(ex, canonical_t; clean=false)
