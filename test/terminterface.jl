using Metatheory.TermInterface, Test

@testset "Expr" begin
  ex = :(f(a, b))
  @test head(ex) == ExprHead(:call)
  @test children(ex) == [:f, :a, :b]
  @test operation(ex) == :f
  @test arguments(ex) == [:a, :b]
  @test ex == maketerm(ExprHead(:call), [:f, :a, :b])

  ex = :(arr[i, j])
  @test head(ex) == ExprHead(:ref)
  @test operation(ex) == :ref
  @test arguments(ex) == [:arr, :i, :j]
  @test ex == maketerm(ExprHead(:ref), [:arr, :i, :j])


  ex = :(i, j)
  @test head(ex) == ExprHead(:tuple)
  @test operation(ex) == :tuple
  @test arguments(ex) == [:i, :j]
  @test children(ex) == [:i, :j]
  @test ex == maketerm(ExprHead(:tuple), [:i, :j])


  ex = Expr(:block, :a, :b, :c)
  @test head(ex) == ExprHead(:block)
  @test operation(ex) == :block
  @test children(ex) == arguments(ex) == [:a, :b, :c]
  @test ex == maketerm(ExprHead(:block), [:a, :b, :c])
end

@testset "Custom Struct" begin
  struct Foo
    args
    Foo(args...) = new(args)
  end
  struct FooHead
    head
  end
  TermInterface.head(::Foo) = FooHead(:call)
  TermInterface.head_symbol(q::FooHead) = q.head
  TermInterface.operation(::Foo) = Foo
  TermInterface.istree(::Foo) = true
  TermInterface.arguments(x::Foo) = [x.args...]
  TermInterface.children(x::Foo) = [operation(x); x.args...]

  t = Foo(1, 2)
  @test head(t) == FooHead(:call)
  @test head_symbol(head(t)) == :call
  @test operation(t) == Foo
  @test istree(t) == true
  @test arguments(t) == [1, 2]
  @test children(t) == [Foo, 1, 2]
end

@testset "Automatically Generated Methods" begin
  @matchable struct Bar
    a
    b::Int
  end

  t = Bar(1, 2)
  @test head(t) == BarHead(:call)
  @test head_symbol(head(t)) == :call
  @test operation(t) == Bar
  @test istree(t) == true
  @test arguments(t) == (1, 2)
  @test children(t) == [Bar, 1, 2]
end