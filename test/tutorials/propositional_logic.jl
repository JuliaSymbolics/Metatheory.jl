# Proving Propositional Logic Statements

using Metatheory, Test

include(joinpath(dirname(pathof(Metatheory)), "../examples/prove.jl"))
include(joinpath(dirname(pathof(Metatheory)), "../examples/propositional_logic_theory.jl"))

@testset "Prop logic" begin
  ex = rewrite(:(((p ⟹ q) && (r ⟹ s) && (p || r)) ⟹ (q || s)), impl)
  @test prove(propositional_logic_theory, ex, 5, 10)


  @test prove(propositional_logic_theory, :((!p == p) == false))
  @test prove(propositional_logic_theory, :((!p == !p) == true))
  @test test_equality(propositional_logic_theory, :((!p || !p) == !p), :(!p || p), :(!(!p && p)))
  @test prove(propositional_logic_theory, :((p || p) == p))
  @test prove(propositional_logic_theory, :((p ⟹ (p || p))))
  @test prove(propositional_logic_theory, :((p ⟹ (p || p)) == ((!(p) && q) ⟹ q)))

  @test prove(propositional_logic_theory, :((p ⟹ (q ⟹ r)) ⟹ ((p ⟹ q) ⟹ (p ⟹ r))))# Frege's theorem

  @test prove(propositional_logic_theory, :(!(p || q) == (!p && !q))) # Demorgan's
end

# Consensus theorem
@test true == prove(propositional_logic_theory, :(((x && y) || (!x && z) || (y && z)) == ((x && y) || (!x && z))))
