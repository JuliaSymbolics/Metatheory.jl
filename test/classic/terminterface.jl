using Metatheory.TermInterface, Test

@testset "Expr" begin
  ex = :(f(a, b))
  @test istree(ex)
  @test is_function_call(ex)
  @test head(ex) == :f
  @test children(ex) == [:a, :b]
  @test ex == maketerm(Expr, :f, [:a, :b])

  ex = :(arr[i, j])
  @test istree(ex)
  @test !is_function_call(ex)
  @test head(ex) == :ref
  @test children(ex) == [:arr, :i, :j]
  @test ex == maketerm(Expr, :ref, [:arr, :i, :j]; is_call = false)


  ex = :(i, j)
  @test istree(ex)
  @test !is_function_call(ex)
  @test head(ex) == :tuple
  @test children(ex) == [:i, :j]
  @test ex == maketerm(Expr, :tuple, [:i, :j]; is_call = false)

  ex = Expr(:block, :a, :b, :c)
  @test istree(ex)
  @test !is_function_call(ex)
  @test head(ex) == :block
  @test children(ex) == [:a, :b, :c]
  @test ex == maketerm(Expr, :block, [:a, :b, :c]; is_call = false)
end

@testset "Custom Struct" begin
  struct Foo
    args
    Foo(args...) = new(args)
  end
  TermInterface.istree(::Foo) = true
  TermInterface.is_function_call(::Foo) = true
  TermInterface.head(::Foo) = Foo
  TermInterface.children(x::Foo) = collect(x.args)

  t = Foo(1, 2)
  @test istree(t)
  @test is_function_call(t)
  @test head(t) == Foo
  @test children(t) == [1, 2]
end

@testset "Automatically Generated Methods" begin
  @matchable struct Bar
    a
    b::Int
  end

  t = Bar(1, 2)
  @test istree(t)
  @test is_function_call(t)
  @test head(t) == Bar
  @test children(t) == (1, 2)
end