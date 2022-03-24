using Metatheory
using Metatheory.EGraphs
using Metatheory.Library
using Rewriters

using Test

Cat = @theory begin
  id(A).(A → A) ⋅ f.(A → B) == f.(A → B)
  f.(A → B) ⋅ id(B).(B → B) == f.(A → B)
  (f.(A → B) ⋅ g.(B → C)) ⋅ h.(C → D) == f.(A → B) ⋅ (g.(B → C) ⋅ h.(C → D))
end

# DOES NOT FIXPOINT!
tag_matcher_t = @theory begin
  sigma(A, B) => σ(A, B).(A ⊗ B → B ⊗ A)
  1(A) => id(A).(A → A)
  :f |> :(f.(A → B))
  :g |> :(g.(B → C))
  :h |> :(h.(B → C))
  :j |> :(j.(B → B))
  :k |> :(j.(C → D))
end

tag_matcher(x) = Chain(tag_matcher_t)(x)

# FIXME TAGGING skip . operator
function tag(x)
  r = Postwalk(PassThrough(If(x -> !istree(x) || operation(x) != :., tag_matcher)))(x)
  println("tagged $x to $(r)")
  r
end

macro areequal_tag(t, exprs...)
  exprs = map(tag, exprs)

  :(areequal($t, $(exprs)...))
end


@testset "Cat" begin
  @test @areequal_tag Cat 1(B) id(B).(B → B)
  @test @areequal_tag Cat (1(A) ⋅ f) f
  @test @areequal_tag Cat (1(A) ⋅ f) f
  @test @areequal_tag Cat (f ⋅ 1(B)) f
  @test @areequal_tag Cat (f ⋅ j) ⋅ j f ⋅ (j ⋅ j)
  @test @areequal_tag Cat (f ⋅ j) ⋅ h f ⋅ (j ⋅ h)
end

MonCat = Cat ∪ monoid(:(⊗), :(:munit)) ∪ @theory begin
  f.(A → B) ⊗ g.(C → D) == (f ⊗ g).(A ⊗ C → B ⊗ D)
  id(A ⊗ B).(A ⊗ B → A ⊗ B) == id(A).(A → A) ⊗ id(B).(B → B)
end

@testset "MonCat" begin
  @test @areequal_tag MonCat 1(A) ⊗ 1(B) 1(A ⊗ B)
  @test @areequal_tag MonCat (f ⊗ g) ((f ⊗ g).(A ⊗ B → B ⊗ C))
  @test @areequal_tag MonCat 1(A ⊗ B) ⋅ (f ⊗ g) (f ⊗ g)
  @test @areequal_tag MonCat ((f ⊗ g) ⋅ 1(B ⊗ C)) (f ⊗ g)
  @test @areequal_tag MonCat 1(A ⊗ B) ⋅ (f ⊗ g) (f ⊗ g).(A ⊗ B → B ⊗ C)
end

SymMonCat =
  MonCat ∪ @theory begin
    σ(A, B).(A ⊗ B → B ⊗ A) ⋅ σ(B, A).(B ⊗ A → A ⊗ B) == id(A ⊗ B).(A ⊗ B → A ⊗ B)

    σ(A, B ⊗ C).(A ⊗ (B ⊗ C) → (B ⊗ C) ⊗ A) == σ(A ⊗ B, C).((A ⊗ B) ⊗ C → C ⊗ (A ⊗ B))
    (f.(A → B) ⊗ g.(C → D)) ⋅ σ(B, D).(B ⊗ D → D ⊗ B) == σ(A, C).(A ⊗ C → C ⊗ A) ⋅ (g.(C → D) ⊗ f.(A → B))
    σ(A, C).(A ⊗ C → C ⊗ A) ⋅ (g.(C → D) ⊗ f.(A → B)) == (f.(A → B) ⊗ g.(C → D)) ⋅ σ(B, D).(B ⊗ D → D ⊗ B)
  end

@testset "SymMonCat" begin
  @test @areequal_tag SymMonCat 1(A) ⊗ 1(B) 1(A ⊗ B)
  @test @areequal_tag SymMonCat (f ⊗ g) (f ⊗ g)
  @test @areequal_tag SymMonCat 1(A ⊗ B) ⋅ (f ⊗ g) (f ⊗ g)
  @test @areequal_tag SymMonCat (f ⊗ g) ⋅ 1(B ⊗ C) (f ⊗ g)
  @test @areequal_tag SymMonCat 1(A ⊗ B) ⋅ (f ⊗ g) (f ⊗ g).(A ⊗ B → B ⊗ C)

  # println("==========================================")

  @test falseormissing(@areequal_tag SymMonCat sigma(A, B) ⋅ sigma(A, B) 1(A ⊗ B))
  @test @areequal_tag SymMonCat sigma(A, B) σ(A, B).(A ⊗ B → B ⊗ A)
  @test @areequal_tag SymMonCat sigma(A, B) ⋅ sigma(B, A) 1(A ⊗ B)
  @test @areequal_tag SymMonCat sigma(B, A) ⋅ sigma(A, B) 1(B ⊗ A)
  @test @areequal_tag SymMonCat (f ⊗ k) ⋅ sigma(B, D) sigma(A, C) ⋅ (k ⊗ f)
  @test @areequal_tag SymMonCat sigma(A, A) ⋅ (f.(A → A) ⊗ g.(A → A)) ⋅ sigma(A, A) g.(A → A) ⊗ f.(A → A)
  @test @areequal_tag SymMonCat sigma(B, A) ⋅ (f.(A → A) ⊗ g.(B → A)) ⋅ sigma(A, A) g.(B → A) ⊗ f.(A → A)
  @test @areequal_tag SymMonCat sigma(B, A) ⋅ (f.(A → C) ⊗ g.(B → D)) ⋅ sigma(C, D) g.(B → D) ⊗ f.(A → C)
end
