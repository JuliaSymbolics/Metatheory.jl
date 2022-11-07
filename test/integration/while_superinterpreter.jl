
## Turing Complete Interpreter
### A Very Tiny Turing Complete Programming Language defined with denotational semantics

# semantica dalle dispense degano
using Metatheory

import Base.ImmutableDict
Mem = Dict{Symbol,Union{Bool,Int}}

read_mem = @theory v σ begin
  (v::Symbol, σ::Mem) => if v == :skip
    σ
  else
    σ[v]
  end
end

@testset "Reading Memory" begin
  ex = :((x), $(Mem(:x => 2)))
  @test true == areequal(read_mem, ex, 2)
end

arithm_rules = @theory a b σ begin
  (a + b, σ::Mem) --> (a, σ) + (b, σ)
  (a * b, σ::Mem) --> (a, σ) * (b, σ)
  (a - b, σ::Mem) --> (a, σ) - (b, σ)
  (a::Int, σ::Mem) --> a
  (a::Int + b::Int) => a + b
  (a::Int * b::Int) => a * b
  (a::Int - b::Int) => a - b
end


@testset "Arithmetic" begin
  @test areequal(read_mem ∪ arithm_rules, :((2 + 3), $(Mem())), 5)
end

# don't need to access memory
bool_rules = @theory a b σ begin
  (a < b, σ::Mem) --> (a, σ) < (b, σ)
  (a || b, σ::Mem) --> (a, σ) || (b, σ)
  (a && b, σ::Mem) --> (a, σ) && (b, σ)
  (!(a), σ::Mem) --> !((a, σ))

  (a::Bool, σ::Mem)   => a
  (!a::Bool)          => !a
  (a::Bool || b::Bool) => (a || b)
  (a::Bool && b::Bool) => (a && b)
  (a::Int < b::Int)   => (a < b)
end

t = read_mem ∪ arithm_rules ∪ bool_rules

@testset "Booleans" begin
  @test areequal(t, :((false || false), $(Mem())), false)

  exx = :((false || false) || !(false || false), $(Mem(:x => 2)))
  g = EGraph(exx)
  saturate!(g, t)
  ex = extract!(g, astsize)
  @test ex == true
  params = SaturationParams(timeout = 12)
  @test areequal(t, exx, true; params = params)

  @test areequal(t, :((2 < 3) && (3 < 4), $(Mem(:x => 2))), true)
  @test areequal(t, :((2 < x) || !(3 < 4), $(Mem(:x => 2))), false)
  @test areequal(t, :((2 < x) || !(3 < 4), $(Mem(:x => 4))), true)
end

if_rules = @theory guard t f σ begin
  (
    if guard
      t
    end
  ) --> (
    if guard
      t
    else
      :skip
    end
  )
  (if guard
    t
  else
    f
  end, σ::Mem) --> (if (guard, σ)
    t
  else
    f
  end, σ)
  (if true
    t
  else
    f
  end, σ::Mem) --> (t, σ)
  (if false
    t
  else
    f
  end, σ::Mem) --> (f, σ)
end

if_language = read_mem ∪ arithm_rules ∪ bool_rules ∪ if_rules


@testset "If Semantics" begin
  @test areequal(if_language, 2, :(if true
    x
  else
    0
  end, $(Mem(:x => 2))))
  @test areequal(if_language, 0, :(if false
    x
  else
    0
  end, $(Mem(:x => 2))))
  @test areequal(if_language, 2, :(if !(false)
    x
  else
    0
  end, $(Mem(:x => 2))))
  params = SaturationParams(timeout = 10)
  @test areequal(if_language, 0, :(if !(2 < x)
    x
  else
    0
  end, $(Mem(:x => 3))); params = params)
end


while_rules = @theory a b σ begin
  (:skip, σ::Mem) --> σ
  ((a; b), σ::Mem) --> ((a, σ); b)
  (a::Int; b) --> b
  (a::Bool; b) --> b
  (σ::Mem; b) --> (b, σ)
  (while a
    b
  end, σ::Mem) --> (if a
    (b;
    while a
      b
    end)
  else
    :skip
  end, σ)
end


write_mem = @theory sym val σ begin
  (sym::Symbol = val, σ::Mem) --> (sym = (val, σ), σ)
  (sym::Symbol = val::Int, σ::Mem) => merge(σ, Dict(sym => val))
end

while_language = if_language ∪ write_mem ∪ while_rules;

@testset "While Semantics" begin
  exx = :((x = 3), $(Mem(:x => 2)))
  g = EGraph(exx)
  saturate!(g, while_language)
  ex = extract!(g, astsize)

  @test areequal(while_language, Mem(:x => 3), exx)

  exx = :((x = 4; x = x + 1), $(Mem(:x => 3)))
  g = EGraph(exx)
  saturate!(g, while_language)
  ex = extract!(g, astsize)

  params = SaturationParams(timeout = 10)
  @test areequal(while_language, Mem(:x => 5), exx; params = params)

  params = SaturationParams(timeout = 14)
  exx = :((
    if x < 10
      x = x + 1
    else
      skip
    end
  ), $(Mem(:x => 3)))
  @test areequal(while_language, Mem(:x => 4), exx; params = params)

  exx = :((while x < 10
    x = x + 1
  end;
  x), $(Mem(:x => 3)))
  g = EGraph(exx)
  params = SaturationParams(timeout = 100, scheduler = Schedulers.SimpleScheduler)
  saturate!(g, while_language, params)
  @test 10 == extract!(g, astsize)
end
