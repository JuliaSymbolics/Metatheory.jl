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
@metatheory_init

const fibo = @theory begin
    x::$Int + y::$Int |> x+y
    fib(n::$Int) |> (n < 2 ? n : :(fib($(n-1)) + fib($(n-2))))
end;

using Suppressor

function compute_fib(n)
    @suppress begin # don't print crap
        g = EGraph(:(fib($n)))
        saturate!(g, fibo; timeout=7000)
        extran = addanalysis!(g, ExtractionAnalysis, astsize)
        extract!(g, extran)
    end
end

end

using BenchmarkTools

ns = 1:2:22

SU_ts = map(ns) do n
    @assert SUFib.compute_fib(n) isa Number
    b = @benchmarkable SUFib.compute_fib($n) seconds=0.2
    mean(run(b)).time / 1e9
end

MT_ts = map(ns) do n
    @assert MTFib.compute_fib(n) isa Number
    b = @benchmarkable MTFib.compute_fib($n) seconds=0.2
    mean(run(b)).time / 1e9
end


using Plots
plot(ns, SU_ts, label="SymbolicUtils", title="fib(n)", ylabel="time (s)", xlabel="n")
plot!(ns, MT_ts, label="Metatheory")
