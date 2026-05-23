using Metatheory
using Metatheory: OptBuffer
using Test

# ============================================================
# Unit tests for segment e-matching
# ============================================================

b = OptBuffer{UInt64}(64)

@testset "Segment: f(~~xs) ematcher matches any arity" begin
  r = @rule f(~~xs) --> g(~~xs)

  # Zero children
  g0 = EGraph(:(f()))
  @test r.ematcher_left!(g0, 0, g0.root, r.stack, b, r.segment_buffer) == 1
  empty!(r.segment_buffer)

  # One child
  g1 = EGraph(:(f(a)))
  @test r.ematcher_left!(g1, 0, g1.root, r.stack, b, r.segment_buffer) == 1
  empty!(r.segment_buffer)

  # Three children
  g3 = EGraph(:(f(a, b, c)))
  @test r.ematcher_left!(g3, 0, g3.root, r.stack, b, r.segment_buffer) == 1
  empty!(r.segment_buffer)

  # Wrong head — no match
  gh = EGraph(:(h(a, b)))
  @test r.ematcher_left!(gh, 0, gh.root, r.stack, b, r.segment_buffer) == 0
  empty!(r.segment_buffer)
end

@testset "Segment: f(~~xs) --> g(~~xs) saturation" begin
  t = @theory begin
    f(~~xs) --> g(~~xs)
  end

  # f() → g()
  g0 = EGraph(:(f()))
  saturate!(g0, t)
  @test in_same_class(g0, addexpr!(g0, :(f())), addexpr!(g0, :(g())))

  # f(a) → g(a)
  g1 = EGraph(:(f(a)))
  saturate!(g1, t)
  @test in_same_class(g1, addexpr!(g1, :(f(a))), addexpr!(g1, :(g(a))))

  # f(a, b, c) → g(a, b, c)
  g3 = EGraph(:(f(a, b, c)))
  saturate!(g3, t)
  @test in_same_class(g3, addexpr!(g3, :(f(a, b, c))), addexpr!(g3, :(g(a, b, c))))
end

@testset "Segment: f(~~xs) == g(~~xs) bidirectional" begin
  t = @theory begin
    f(~~xs) == g(~~xs)
  end

  # f(a, b) ≡ g(a, b)
  g2 = EGraph(:(f(a, b)))
  saturate!(g2, t)
  @test in_same_class(g2, addexpr!(g2, :(f(a, b))), addexpr!(g2, :(g(a, b))))

  # g(x) ≡ f(x)  (reverse direction triggered)
  g_rev = EGraph(:(g(x)))
  saturate!(g_rev, t)
  @test in_same_class(g_rev, addexpr!(g_rev, :(g(x))), addexpr!(g_rev, :(f(x))))
end

@testset "Segment: fixed prefix/suffix — drop segment" begin
  t = @theory begin
    f(~a, ~~xs) --> h(~a)
  end

  g_drop = EGraph(:(f(1, 2, 3)))
  saturate!(g_drop, t)
  @test in_same_class(g_drop, addexpr!(g_drop, :(f(1, 2, 3))), addexpr!(g_drop, :(h(1))))
end

@testset "Segment: fixed prefix and suffix — reorder" begin
  # f(~a, ~~xs, ~b) --> g(~b, ~a)
  t = @theory begin
    f(~a, ~~xs, ~b) --> g(~b, ~a)
  end

  # f(1, 2, 3, 4): ~a=1, ~~xs=[2,3], ~b=4 → g(4, 1)
  g_reorder = EGraph(:(f(1, 2, 3, 4)))
  saturate!(g_reorder, t)
  @test in_same_class(g_reorder, addexpr!(g_reorder, :(f(1, 2, 3, 4))), addexpr!(g_reorder, :(g(4, 1))))

  # f(1, 4): arity=2 → ~a=1, ~~xs=[], ~b=4 → g(4, 1)
  g_min = EGraph(:(f(1, 4)))
  saturate!(g_min, t)
  @test in_same_class(g_min, addexpr!(g_min, :(f(1, 4))), addexpr!(g_min, :(g(4, 1))))

  # f(1): arity=1, needs >= 2 → no match
  g_too_small = EGraph(:(f(1)))
  saturate!(g_too_small, t)
  @test !in_same_class(g_too_small, addexpr!(g_too_small, :(f(1))), addexpr!(g_too_small, :(g(1, 1))))
end

@testset "Segment: extract segment onto RHS" begin
  # f(~a, ~~xs, ~b) --> g(~~xs)
  t = @theory begin
    f(~a, ~~xs, ~b) --> g(~~xs)
  end

  # f(1, 2, 3, 4): ~~xs=[2,3] → g(2, 3)
  g_ex = EGraph(:(f(1, 2, 3, 4)))
  saturate!(g_ex, t)
  @test in_same_class(g_ex, addexpr!(g_ex, :(f(1, 2, 3, 4))), addexpr!(g_ex, :(g(2, 3))))

  # f(1, 4): ~~xs=[] → g()
  g_empty = EGraph(:(f(1, 4)))
  saturate!(g_empty, t)
  @test in_same_class(g_empty, addexpr!(g_empty, :(f(1, 4))), addexpr!(g_empty, :(g())))
end

@testset "Segment: only-suffix pattern" begin
  # f(~~xs, ~b) --> h(~b, ~~xs)
  t = @theory begin
    f(~~xs, ~b) --> h(~b, ~~xs)
  end

  # f(1, 2, 3): ~~xs=[1,2], ~b=3 → h(3, 1, 2)
  g_sf = EGraph(:(f(1, 2, 3)))
  saturate!(g_sf, t)
  @test in_same_class(g_sf, addexpr!(g_sf, :(f(1, 2, 3))), addexpr!(g_sf, :(h(3, 1, 2))))
end

@testset "Segment: classical rewriting still works" begin
  # Classical (non-egraph) rewriting with ~~xs must be unaffected
  r_classic = @rule f(~~xs) --> g(~~xs)
  @test r_classic(:(f(1, 2, 3))) == :(g(1, 2, 3))
  @test r_classic(:(f()))       == :(g())
  @test r_classic(:(h(1, 2)))   === nothing
end

@testset "Non-segment theories: correctness unchanged" begin
  # A purely non-segment theory must give identical results to before
  comm_monoid = @theory begin
    ~a * ~b         --> ~b * ~a
    ~a * 1          --> ~a
    1 * ~a          --> ~a
    ~a * (~b * ~c)  --> (~a * ~b) * ~c
  end

  g = EGraph(:(a * (b * (1 * c))))
  saturate!(g, comm_monoid)
  @test in_same_class(g, g.root, addexpr!(g, :((a * b) * c)))
end
