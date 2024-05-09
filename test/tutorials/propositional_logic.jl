# Proving Propositional Logic Statements

using Metatheory, Test

include(joinpath(dirname(pathof(Metatheory)), "../examples/prove.jl"))
include(joinpath(dirname(pathof(Metatheory)), "../examples/propositional_logic_theory.jl"))

@testset "Prop logic" begin
  ex = rewrite(:(((p ⟹ q) && (r ⟹ s) && (p || r)) ⟹ (q || s)), impl)
  @test prove(propositional_logic_theory, ex, 5, 10)


  @test @areequal propositional_logic_theory ((!p == p) == false) true
  @test @areequal propositional_logic_theory ((!p == !p) == true) true
  @test @areequal propositional_logic_theory ((!p || !p) == !p) (!p || p) !(!p && p) true
  @test @areequal propositional_logic_theory (p || p) p
  @test @areequal propositional_logic_theory ((p ⟹ (p || p))) true
  @test @areequal propositional_logic_theory ((p ⟹ (p || p)) == ((!(p) && q) ⟹ q)) == true true


  @test @areequal propositional_logic_theory (p ⟹ (q ⟹ r)) ⟹ ((p ⟹ q) ⟹ (p ⟹ r)) true # Frege's theorem

  @test @areequal propositional_logic_theory (!(p || q) == (!p && !q)) true # Demorgan's
end

# Consensus theorem
# @test_broken @areequal propositional_logic_theory ((x && y) || (!x && z) || (y && z)) ((x && y) || (!x && z)) true
