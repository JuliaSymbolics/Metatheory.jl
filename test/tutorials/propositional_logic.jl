# Proving Propositional Logic Statements

using Test
using Metatheory
using TermInterface

include(joinpath(dirname(pathof(Metatheory)), "../examples/propositional_logic_theory.jl"))

@testset "Prop logic" begin
  ex = rewrite(:(((p ⟹ q) && (r ⟹ s) && (p || r)) ⟹ (q || s)), impl)
  @test prove(propositional_logic_theory, ex, 5, 10, 5000)


  @test @areequal propositional_logic_theory true ((!p == p) == false)
  @test @areequal propositional_logic_theory true ((!p == !p) == true)
  @test @areequal propositional_logic_theory true ((!p || !p) == !p) (!p || p) !(!p && p)
  @test @areequal propositional_logic_theory p (p || p)
  @test @areequal propositional_logic_theory true ((p ⟹ (p || p)))
  @test @areequal propositional_logic_theory true ((p ⟹ (p || p)) == ((!(p) && q) ⟹ q)) == true

  # Frege's theorem
  @test @areequal propositional_logic_theory true (p ⟹ (q ⟹ r)) ⟹ ((p ⟹ q) ⟹ (p ⟹ r))

  # Demorgan's
  @test @areequal propositional_logic_theory true (!(p || q) == (!p && !q))

  # Consensus theorem
  # @test_broken @areequal propositional_logic_theory true ((x && y) || (!x && z) || (y && z)) ((x && y) || (!x && z))
end
