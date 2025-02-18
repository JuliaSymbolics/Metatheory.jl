# Proving Propositional Logic Statements

using Metatheory, Test

include(joinpath(dirname(pathof(Metatheory)), "../examples/prove.jl"))
include(joinpath(dirname(pathof(Metatheory)), "../examples/propositional_logic_theory.jl"))

@testset "Prop logic" begin
  ex = rewrite(:(((p ⟹ q) && (r ⟹ s) && (p || r)) ⟹ (q || s)), impl)
  @test true == prove(propositional_logic_theory, ex, 5, 10)[1]


  @test true == prove(propositional_logic_theory, :((!p == p) == false))[1]
  @test true == prove(propositional_logic_theory, :((!p == !p) == true))[1]
  @test test_equality(propositional_logic_theory, :((!p || !p) == !p), :(!p || p), :(!(!p && p)))
  @test true == prove(propositional_logic_theory, :((p || p) == p))[1]
  @test true == prove(propositional_logic_theory, :((p ⟹ (p || p))))[1]
  @test true == prove(propositional_logic_theory, :((p ⟹ (p || p)) == ((!(p) && q) ⟹ q)))[1]

  @test true == prove(propositional_logic_theory, :((p ⟹ (q ⟹ r)) ⟹ ((p ⟹ q) ⟹ (p ⟹ r))))[1] # Frege's theorem

  @test true == prove(propositional_logic_theory, :(!(p || q) == (!p && !q)))[1] # Demorgan's
end

# Consensus theorem
@test true == prove(propositional_logic_theory, :(((x && y) || (!x && z) || (y && z)) == ((x && y) || (!x && z))))[1]
