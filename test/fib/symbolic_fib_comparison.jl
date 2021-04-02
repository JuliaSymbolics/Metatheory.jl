# Thanks to Mason Protter for this benchmark

module SUFib
using SymbolicUtils
using SymbolicUtils.Rewriters

@syms fib(x::Int)::Int

const rset = [
    @rule fib(0) => 0
    @rule fib(1) => 1
    @rule fib(~n) => fib(~n - 1) + fib(~n - 2)
] |> Chain |> Postwalk |> Fixpoint

compute_fib(n) = rset(fib(n))

end


module MTFib

using Metatheory
using Metatheory.EGraphs

@metatheory_init ()

const fibo = @theory begin
    x::Int + y::Int |> x+y
    fib(n::Int) |> (n < 2 ? n : :(fib($(n-1)) + fib($(n-2))))
end;

function compute_fib(n)
    params = SaturationParams(timeout = 7000, 
        scheduler=Schedulers.SimpleScheduler)
    g = EGraph(:(fib($n)))
    saturate!(g, fibo, params)
    extract!(g, astsize)
end

end

using BenchmarkTools

ns = 1:2:22

SU_ts = map(ns) do n
    println(n)
    @assert SUFib.compute_fib(n) isa Number
    b = @benchmarkable SUFib.compute_fib($n) seconds=0.2
    mean(run(b)).time / 1e9
end

MT_ts = map(ns) do n
    println(n)
    @assert MTFib.compute_fib(n) isa Number
    b = @benchmarkable MTFib.compute_fib($n) seconds=0.2
    mean(run(b)).time / 1e9
end


using Plots
pyplot()

font = "DejaVu Math TeX Gyre"
# default(titlefont=font, legendfont=font, fontfamily=font)
default(fontfamily=font, markerstrokewidth=0)


plot(ns, SU_ts, label="SymbolicUtils.jl", title="fib(n)", ylabel="Time (s)", xlabel="n", 
    color = :black, legend = :topleft, line=:dot,  # m=(:cross, :blue),
    size=(320,220), legendfontsize = 9, titlefontsize=12)
plot!(ns, MT_ts, label="Metatheory.jl", color = :black) # m = (:circle, :orange) )
savefig("benchmarks/figures/fib.pdf")
