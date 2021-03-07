using Metatheory
using Metatheory.EGraphs
using Metatheory.Library

Context = commutative_monoid(:∧, :(:I)) ∪ @theory begin
    (A.Ob ⊢ id(A)) == (A.Ob ∧ id(A).(A→A) ⊢ id(A))
end

println(Context)

using Test
@testset "Context" begin
    @testset "Commutative Monoid in the Context" begin
        @test @areequal Context (A ∧ B⊢ f) (B ∧ A ⊢ f)
        @test @areequal Context (A ∧ (B ∧ C) ⊢ f) ((A∧B) ∧ C ⊢ f)
        @test @areequal Context (A ∧ (B ∧ C) ⊢ f) ((B∧A) ∧ C ⊢ f)
        @test @areequal Context (A ∧ (B ∧ C) ⊢ f) ((C∧B) ∧ A ⊢ f)
        @test @areequal Context ((C ∧ A) ∧ B ⊢ f) ((C ∧ B) ∧ A ⊢ f)
        @test @areequal Context ((A ∧ A) ∧ B ⊢ f) (B ∧ A ⊢ f)
        @test @areequal Context (B∧(A ∧ A) ∧ B ⊢ f) (B ∧ A ⊢ f)
    end
    @testset "Not equal things" begin
        @test ! @areequal Context (A∧B ⊢ A)  (A ⊢ A)
        @test ! @areequal Context (A ⊢ A)  (A∧B ⊢ A)
        @test ! @areequal Context (A ⊢ A)  (A ⊢ A∧B)
        @test ! @areequal Context (A ⊢ A)  (A ⊢ A ∨ B)
    end
    @testset "Unitality" begin
        @test @areequal Context A.Ob ⊢ id(A)        A.Ob∧ id(A).(A→A) ⊢ id(A)
        @test @areequal Context ((A.Ob ∧ A.Ob) ⊢ id(A))        ((A.Ob) ⊢ id(A))
        @test @areequal Context (A.Ob ∧ A.Ob) ⊢ id(A)        A.Ob ∧id(A).(A→A)⊢ id(A)
        @test @areequal Context A.Ob ∧ B.Ob ⊢ id(A)        B.Ob ∧ A.Ob ∧ id(A).(A→A) ⊢ id(A)
        @test @areequal Context (A.Ob ∧ B.Ob ⊢ id(A))        A.Ob ∧ id(A).(A→A) ⊢ id(A)
        @test ! @areequal Context A.Ob ∧ B.Ob ⊢ id(A)  B.Ob ∧ id(B).(A→A)⊢ id(B)
    end
end
