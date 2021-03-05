using Metatheory
using Metatheory.EGraphs
using Test

Cat = @theory begin
    1(A) => id(A).(A→A)
    id(A).(A→A) ⋅ f.(A→B) => f.(A→B)
    f.(A→B)⋅id(B).(B→B) => f.(A→B)
    (f.(A→B)⋅g.(B→C))⋅h.(C→D) => f.(A→B)⋅(g.(B→C)⋅h.(C→D))
end


@testset "Cat" begin
    @test @areequal Cat 1(B) id(B).(B→B)
    @test @areequal Cat (id(A).(A→A)⋅f.(A→B)) f.(A→B)
    @test @areequal Cat (1(A)⋅f.(A→B)) f.(A→B)
    @test @areequal Cat (f.(A→B)⋅1(B)) f.(A→B)
    @test @areequal Cat (f.(A→B)⋅g.(B→B))⋅g.(B→B) f.(A→B)⋅(g.(B→B)⋅g.(B→B))
    @test @areequal Cat (f.(A→B)⋅g.(B→B))⋅h.(B→C) f.(A→B)⋅(g.(B→B)⋅h.(B→C))
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
    (f⊗g).(A⊗C→B⊗D) => f.(A→B)⊗g.(C→D)
    id(A⊗B).(A⊗B→A⊗B) => id(A).(A→A)⊗id(B).(B→B)
end

@testset "MonCat" begin
    @test @areequal MonCat 1(A)⊗1(B) 1(A⊗B)
    @test @areequal MonCat (f.(A→B)⊗g.(B→C)) (f.(A→B)⊗g.(B→C))
    @test @areequal MonCat 1(A⊗B)⋅(f.(A→B)⊗g.(B→C)) (f.(A→B)⊗g.(B→C))
    @test @areequal MonCat (f.(A→B)⊗g.(B→C))⋅ 1(A⊗B) (f.(A→B)⊗g.(B→C))
    @test @areequal MonCat 1(A⊗B)⋅(f.(A→B)⊗g.(B→C)) (f⊗g).(A⊗B→B⊗C)
end

SymMonCat = MonCat ∪ @theory begin
    sigma(A, B) => σ(A, B).(A⊗B→B⊗A)
    σ(A, B).(A⊗B→B⊗A) ⋅ σ(B,A).(B⊗A→A⊗B) => id(A⊗B).(A⊗B→A⊗B)
    σ(A, B⊗C).(A⊗(B⊗C)→A⊗(B⊗C)) => σ(A⊗B, C).((A⊗B)⊗C→(A⊗B)⊗C)
    (f.(A→B)⊗g.(C→D))⋅σ(B,D).(B⊗D→D⊗B) => σ(A,C).(A⊗C→C⊗A) ⋅ (g.(C→D)⊗f.(A→B))
    σ(A,C).(A⊗C→C⊗A) ⋅ (g.(C→D)⊗f.(A→B)) => (f.(A→B)⊗g.(C→D))⋅σ(B,D).(B⊗D→D⊗B)
end

@testset "SymMonCat" begin
    @test @areequal SymMonCat 1(A)⊗1(B) 1(A⊗B)
    @test @areequal SymMonCat (f.(A→B)⊗g.(B→C)) (f.(A→B)⊗g.(B→C))
    @test @areequal SymMonCat 1(A⊗B)⋅(f.(A→B)⊗g.(B→C)) (f.(A→B)⊗g.(B→C))
    @test @areequal SymMonCat (f.(A→B)⊗g.(B→C))⋅ 1(A⊗B) (f.(A→B)⊗g.(B→C))
    @test @areequal SymMonCat 1(A⊗B)⋅(f.(A→B)⊗g.(B→C)) (f⊗g).(A⊗B→B⊗C)
    @test false == @areequal SymMonCat sigma(A,B)⋅sigma(A,B)   1(A⊗B)
    @test @areequal SymMonCat sigma(A,B) σ(A,B).(A⊗B→B⊗A)
    @test @areequal SymMonCat sigma(A,B)⋅sigma(B,A) 1(A⊗B)
    @test @areequal SymMonCat sigma(B,A)⋅sigma(A,B) 1(B⊗A)
    @test @areequal SymMonCat (f.(A→B)⊗g.(C→D))⋅sigma(B,D) sigma(A,C)⋅(g.(C→D)⊗f.(A→B))
    @test @areequal SymMonCat sigma(A,A)⋅(f.(A→A)⊗g.(A→A))⋅sigma(A,A) g.(A→A)⊗f.(A→A)
    @test @areequal SymMonCat sigma(B,A)⋅(f.(A→A)⊗g.(B→A))⋅sigma(A,A) g.(B→A)⊗f.(A→A)
    @test @areequal SymMonCat sigma(B,A)⋅(f.(A→C)⊗g.(B→D))⋅sigma(C,D) g.(B→D)⊗f.(A→C)
end
