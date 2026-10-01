using Test
using Metatheory

# Issue #224: independent e-graphs on separate threads must not race on shared Pats
# or shared RewriteRule stacks/segment buffers.

make_comm_assoc_theory() = @theory a b c begin
  a + b == b + a
  a * b == b * a
  a + (b + c) == (a + b) + c
  a * (b * c) == (a * b) * c
end

# Composite ground subpattern `g(1, 2)` forces lookup_pat's PAT_EXPR branch
# (which previously wrote child e-class ids into the shared child Pat.n).
make_theory_with_ground() = @theory a b begin
  f(a, g(1, 2)) == h(a)
  a + b == b + a
  a + 0 == a
end

function walk_pats!(f, p::Pat)
  f(p)
  for c in p.children
    walk_pats!(f, c)
  end
end

function snapshot_pat_buffers(theory)
  snaps = Memory{UInt64}[]
  for r in theory
    walk_pats!(p -> push!(snaps, copy(p.n.data)), r.left)
    walk_pats!(p -> push!(snaps, copy(p.n.data)), r.right)
  end
  snaps
end

function assert_pat_buffers_unchanged(theory, snaps)
  i = 1
  for r in theory
    for side in (r.left, r.right)
      walk_pats!(side) do p
        @test p.n.data == snaps[i]
        i += 1
      end
    end
  end
  @test i == length(snaps) + 1
end

function pat_buffers_unchanged(theory, snaps)
  i = 1
  ok = true
  for r in theory
    for side in (r.left, r.right)
      walk_pats!(side) do p
        if ok
          ok = (p.n.data == snaps[i])
          i += 1
        end
      end
    end
  end
  return ok && i == length(snaps) + 1
end

const SHARED_COMM_ASSOC = make_comm_assoc_theory()
const SHARED_WITH_GROUND = make_theory_with_ground()

@testset "Issue #224: patterns not mutated by saturation" begin
  theory = make_comm_assoc_theory()
  snap = snapshot_pat_buffers(theory)
  g = EGraph{Expr}(:(1 + (2 + (3 + (4 + (5 + 6))))))
  saturate!(g, theory, SaturationParams(timeout = 50))
  assert_pat_buffers_unchanged(theory, snap)

  theory2 = make_theory_with_ground()
  snap2 = snapshot_pat_buffers(theory2)
  # Vary surrounding terms so ground lookup yields nontrivial child ids
  g2 = EGraph{Expr}(:(k(1) + k(2) + f(x, g(1, 2)) + f(y, g(1, 2))))
  saturate!(g2, theory2, SaturationParams(timeout = 50))
  assert_pat_buffers_unchanged(theory2, snap2)
end

@testset "Issue #224: independent e-graphs on threads" begin
  n = 200
  errors = Vector{Any}(undef, n)
  fill!(errors, nothing)

  Threads.@threads for i in 1:n
    try
      # Fresh theory objects (issue's literal repro style)
      theory = make_comm_assoc_theory()
      snap = snapshot_pat_buffers(theory)
      g = EGraph{Expr}(:(1 + (2 + (3 + (4 + (5 + 6))))))
      saturate!(g, theory, SaturationParams(timeout = 100))
      pat_buffers_unchanged(theory, snap) || error("fresh theory pattern buffers mutated")

      # Composite ground lookup_pat path; vary pre-context so ids differ per iteration
      theory_g = make_theory_with_ground()
      snap_g = snapshot_pat_buffers(theory_g)
      pre = Expr(:call, :+, [Expr(:call, :k, j) for j in 1:(i % 7)]..., 0)
      g2 = EGraph{Expr}(:($pre + f(x, g(1, 2)) + f(y, g(1, 2))))
      saturate!(g2, theory_g, SaturationParams(timeout = 50))
      pat_buffers_unchanged(theory_g, snap_g) || error("ground theory pattern buffers mutated")

      # Shared const theory: must not race on RewriteRule.stack / segment_buffer
      g3 = EGraph{Expr}(:(1 + (2 + (3 + (4 + (5 + 6))))))
      saturate!(g3, SHARED_COMM_ASSOC, SaturationParams(timeout = 100))
      g4 = EGraph{Expr}(:($pre + f(x, g(1, 2))))
      saturate!(g4, SHARED_WITH_GROUND, SaturationParams(timeout = 50))
    catch e
      errors[i] = e
    end
  end

  failed = findall(!isnothing, errors)
  if !isempty(failed)
    @info "first thread failure" exception = errors[failed[1]] nthreads = Threads.nthreads()
  end
  @test isempty(failed)
end
