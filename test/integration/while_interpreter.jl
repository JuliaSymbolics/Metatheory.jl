
## Turing Complete Interpreter
### A Very Tiny Turing Complete Programming Language defined with denotational semantics

# semantica dalle dispense degano

using Metatheory
using Metatheory.Rewriters

Mem = Dict{Symbol,Union{Bool,Int}}

read_mem = @theory v σ begin
  (v::Symbol, σ) => σ[v]
end

@testset "Reading Memory" begin
  @test 2 == rewrite(:((x), $(Mem(:x => 2))), read_mem; order = :inner)
end

arithm_rules = @theory a b n σ begin
  (a + b, σ) --> (a, σ) + (b, σ)
  (a * b, σ) --> (a, σ) * (b, σ)
  (a - b, σ) --> (a, σ) - (b, σ)
  (a::Int + b::Int) => a + b
  (a::Int * b::Int) => a * b
  (a::Int - b::Int) => a - b
  (n::Int, σ)       => n
end

strategy = (Fixpoint ∘ Postwalk ∘ Fixpoint ∘ Chain)

eval_arithm(ex, mem) = strategy(read_mem ∪ arithm_rules)(:($ex, $mem))


@testset "Arithmetic" begin
  @test 5 == eval_arithm(:(2 + 3), Mem())
  @test 4 == eval_arithm(:(2 + x), Mem(:x => 2))
end

# don't need to access memory
bool_rules = @theory a b σ begin
  (a::Bool ∨ b::Bool) => (a || b)
  (a::Bool ∧ b::Bool) => (a && b)
  (a::Int < b::Int) => (a < b)
  ¬a::Bool => !a
  (a::Bool, σ) => a
  (a < b, σ) => (eval_arithm(a, σ) < eval_arithm(b, σ))
  (¬b, σ) => !eval_bool(b, σ)
  (a ∨ b, σ) --> (a, σ) ∨ (b, σ)
  (a ∧ b, σ) --> (a, σ) ∧ (b, σ)
end

eval_bool(ex, mem) = strategy(bool_rules)(:($ex, $mem))

@testset "Booleans" begin
  @test false == eval_bool(:(false ∨ false), Mem())
  @test true == eval_bool(:((false ∨ false) ∨ ¬(false ∨ false)), Mem(:x => 2))
  @test true == eval_bool(:((2 < 3) ∧ (3 < 4)), Mem(:x => 2))
  @test false == eval_bool(:((2 < x) ∨ ¬(3 < 4)), Mem(:x => 2))
  @test true == eval_bool(:((2 < x) ∨ ¬(3 < 4)), Mem(:x => 4))
end

if_rules = @theory guard t f σ begin
  (if guard
    t
  end, σ) --> (if guard
    t
  else
    :skip
  end, σ)
  (if guard
    t
  else
    f
  end, σ) => (eval_bool(guard, σ) ? :($t, $σ) : :($f, $σ))
end

eval_if(ex::Expr, mem::Mem) = strategy(read_mem ∪ arithm_rules ∪ if_rules)(:($ex, $mem))

@testset "If Semantics" begin
  @test 2 == eval_if(:(
    if true
      x
    else
      0
    end
  ), Mem(:x => 2))
  @test 0 == eval_if(:(
    if false
      x
    else
      0
    end
  ), Mem(:x => 2))
  @test 2 == eval_if(:(
    if ¬(false)
      x
    else
      0
    end
  ), Mem(:x => 2))
  @test 0 == eval_if(:(
    if ¬(2 < x)
      x
    else
      0
    end
  ), Mem(:x => 3))
end

while_rules = @theory guard a b σ begin
  (:skip, σ) --> σ
  ((:skip; b), σ) --> (b, σ)
  ((a; b), σ) => begin
    r = eval_while(a, σ)
    (r isa Mem) ? :($b, $r) : :($b, $σ)
  end
  (while guard
    a
  end, σ) --> (if guard
    (a;
    while guard
      a
    end)
  else
    :skip
  end, σ)
end


write_mem = @theory sym val σ begin
  (sym::Symbol = val, σ) => (σ[sym] = eval_arithm(val, σ);
  σ)
end

while_language = write_mem ∪ read_mem ∪ arithm_rules ∪ if_rules ∪ while_rules;

eval_while(ex, mem) = strategy(while_language)(:($ex, $mem))

@testset "While Semantics" begin
  # @test Mem(:x => 3) == eval_while(:((x = 3)), Mem(:x => 2))
  @test Mem(:x => 5) == eval_while(:(x = 4; x = x + 1), Mem(:x => 3))
  @test Mem(:x => 4) == eval_while(:(
    if x < 10
      x = x + 1
    end
  ), Mem(:x => 3))
  # @test 10 == eval_while( :( while x < 10; x = x + 1 end ; x ) , Mem(:x => 3))
  # @test 50 == eval_while( :( while x < y; (x = x + 1; y = y - 1) end ; x ) , Mem(:x => 0, :y => 100))
end
