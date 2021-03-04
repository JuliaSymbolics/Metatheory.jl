
Cat = @theory begin
    1(A) => id(A).(A→A)
    id(A).(A→A) ⋅ f.(A→B) => f.(A→B)
    f.(A→B) ⋅ id(A).(A→A) => f.(A→B)
    f.(A→B)⋅id(B).(B→B) => f.(A→B)
    (f.(A→B)⋅g.(B→C))⋅h.(C→D) => f.(A→B)⋅(g.(B→C)⋅h.(C→D))
end

using Test

@testset "Cat" begin
@test @areequal Cat 1(B) id(B).(B→B)
@test @areequal Cat (id(A).(A→A)⋅f.(A→B)) f.(A→B)
@test @areequal Cat (1(A)⋅f.(A→B)) f.(A→B)
@test @areequal Cat (f.(A→B)⋅1(B)) f.(A→B)
@test @areequal Cat (f.(A→B)⋅g.(B→B))⋅g.(B→B) f.(A→B)⋅(g.(B→B)⋅g.(B→B))
@test @areequal Cat (f.(A→B)⋅g.(B→B))⋅h.(B→C) f.(A→B)⋅(g.(B→B)⋅h.(B→C))
# areequal(CatTyped, :(f.(A→B)⋅1(B)), :f; timeout=100)
end

MonCat = @theory begin
    1(A) => id(A).(A→A)
    id(A).(A→A) ⋅ f.(A→B) => f.(A→B)
    f.(A→B) ⋅ id(A).(A→A) => f.(A→B)
    f.(A→B)⋅id(B).(B→B) => f.(A→B)
    (f.(A→B)⋅g.(B→C))⋅h.(C→D) => f.(A→B)⋅(g.(B→C)⋅h.(C→D))

    munit() => munit()
    A⊗munit() => A
    munit()⊗A => A

    (f⊗g)⊗h => f⊗(g⊗h)  # associativity for both obs and homs
    f.(A→B)⊗g.(C→D) => (f⊗g).(A⊗C→B⊗D)
    id(A⊗B).(A⊗B→A⊗B) => id(A).(A→A)⊗id(B).(B→B)
end

@testset "MonCat" begin
    @test @areequal MonCat 1(A)⊗1(B) 1(A⊗B)
    @test @areequal MonCat (f.(A→B)⊗g.(B→C)) (f.(A→B)⊗g.(B→C))
    @test @areequal MonCat 1(A⊗B)⋅(f.(A→B)⊗g.(B→C)) (f.(A→B)⊗g.(B→C))
    @test @areequal MonCat (f.(A→B)⊗g.(B→C))⋅ 1(A⊗B) (f.(A→B)⊗g.(B→C))
    @test @areequal MonCat 1(A⊗B)⋅(f.(A→B)⊗g.(B→C)) (f⊗g).(A⊗B→B⊗C)
end
