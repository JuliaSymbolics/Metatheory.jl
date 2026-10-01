using Test
using Metatheory

# Issue #224: independent e-graphs saturated on separate threads must not race.
# Root cause: @rule/@theory splice shared Pat buffers; instantiate/lookup must not mutate them.

make_comm_assoc_theory() = @theory a b c begin
  a + b == b + a
  a * b == b * a
  a + (b + c) == (a + b) + c
  a * (b * c) == (a * b) * c
end

# Ground RHS exercises lookup_pat on a shared pattern buffer.
make_theory_with_ground() = @theory a begin
  a + 0 == a
  a * 1 == a
  a + a == 2 * a
end

function snapshot_pat_buffers(theory)
  [(copy(r.left.n.data), copy(r.right.n.data)) for r in theory]
end

function assert_pat_buffers_unchanged(theory, snap)
  for (rule, (l0, r0)) in zip(theory, snap)
    @test rule.left.n.data == l0
    @test rule.right.n.data == r0
  end
end

@testset "Issue #224: patterns not mutated by saturation" begin
  theory = make_comm_assoc_theory()
  snap = snapshot_pat_buffers(theory)
  g = EGraph{Expr}(:(1 + (2 + (3 + (4 + (5 + 6))))))
  saturate!(g, theory, SaturationParams(timeout = 50))
  assert_pat_buffers_unchanged(theory, snap)

  theory2 = make_theory_with_ground()
  snap2 = snapshot_pat_buffers(theory2)
  g2 = EGraph{Expr}(:(x + 0))
  saturate!(g2, theory2, SaturationParams(timeout = 50))
  assert_pat_buffers_unchanged(theory2, snap2)
end

@testset "Issue #224: independent e-graphs on threads" begin
  # Non-vacuous with -t 1: still run many independent saturations and check success.
  n = 200
  errors = Vector{Any}(undef, n)
  fill!(errors, nothing)

  Threads.@threads for i in 1:n
    try
      theory = make_comm_assoc_theory()
      snap = snapshot_pat_buffers(theory)
      g = EGraph{Expr}(:(1 + (2 + (3 + (4 + (5 + 6))))))
      saturate!(g, theory, SaturationParams(timeout = 100))
      for (rule, (l0, r0)) in zip(theory, snap)
        rule.left.n.data == l0 || error("left pattern buffer mutated")
        rule.right.n.data == r0 || error("right pattern buffer mutated")
      end

      # Also exercise ground-pattern lookup_pat under concurrency
      theory_g = make_theory_with_ground()
      snap_g = snapshot_pat_buffers(theory_g)
      g2 = EGraph{Expr}(:((x + 0) * 1))
      saturate!(g2, theory_g, SaturationParams(timeout = 50))
      for (rule, (l0, r0)) in zip(theory_g, snap_g)
        rule.left.n.data == l0 || error("ground theory left pattern mutated")
        rule.right.n.data == r0 || error("ground theory right pattern mutated")
      end
    catch e
      errors[i] = e
    end
  end

  failed = findall(!isnothing, errors)
  if !isempty(failed)
    @info "first thread failure" exception = errors[failed[1]]
  end
  @test isempty(failed)
  @test Threads.nthreads() >= 1  # records thread count; meaningful work is the loop above
end
