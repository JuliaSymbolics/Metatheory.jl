
@testset "Rule making" begin
    @test (@rule a + a => 2a) isa Rule
    r = Rule(:(a + a => 2a))
    rm = @rule a + a => 2a
    @test r.left == rm.left
    @test r.right == rm.right
    @test r.expr == rm.expr
end

@testset "MatchCore Theory Compilation" begin
    theory = :(
        begin
            :($a + $(&a)) => :(2 * $a)
            :($b + $(&b) + $(&b)) => :(3 * $b)
            :($i) => i
        end
    ) |> rmlines
    theory_macro = @theory begin
        a + a => 2a
        b + b + b => 3b
    end
    @test (Metatheory.Classic.theory_block(theory_macro) == theory)
end
