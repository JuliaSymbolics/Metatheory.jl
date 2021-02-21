costfun(n) = 1
costfun(n::Expr) = n.args[2] == :a ? 1 : 100

moveright = @theory begin
    (:b * (:a * c)) => (:a * (:b * c))
end

expr = :(a * (a * (b * (a * b))))
res = rewrite( expr , moveright)
println(res)

g = EGraph(expr)
saturate!(g, moveright)
extractor = addanalysis!(g, ExtractionAnalysis, costfun)
resg = extract!(g, extractor)
println(resg)

@testset "Symbols in Right hand" begin
    @test resg == res == :(a * (a * (a * (b * b))))
end
