
## Turing Complete Interpreter
### A Very Tiny Turing Complete Programming Language defined with denotational semantics

# semantica dalle dispense degano

using Metatheory
using SymbolicUtils
using SymbolicUtils.Rewriters

Mem = Dict{Symbol, Union{Bool, Int}}

read_mem = @theory begin
	(v::Symbol, mem) |> mem[v]
end

@testset "Reading Memory" begin
	@test 2 == rewrite(:((x), $(Mem(:x => 2))), read_mem; order=:inner)
end

arithm_rules = @theory begin
	(a + b, σ) 		  => (a, σ) + (b, σ)
	(a * b, σ) 		  => (a, σ) * (b, σ)
	(a - b, σ) 		  => (a, σ) - (b, σ)
	(a::Int + b::Int) |> a + b
	(a::Int * b::Int) |> a * b
	(a::Int - b::Int) |> a - b
	(n::Int, σ) |> n
end

strategy = (Fixpoint ∘ Postwalk ∘ Fixpoint ∘ Chain)

eval_arithm(ex, mem) = 
	strategy(read_mem ∪ arithm_rules)(:($ex, $mem))


@testset "Arithmetic" begin
	@test 5 == eval_arithm(:(2 + 3), Mem())
	@test 4 == eval_arithm(:(2 + x), Mem(:x => 2))
end

# don't need to access memory
bool_rules = @theory begin
	(a::Bool ∨ b::Bool) |> (a || b)
	(a::Bool ∧ b::Bool) |> (a && b)
	(a::Int < b::Int) 	|> (a < b)
	¬a::Bool 			|> !a
	(bv::Bool, σ) 		|> bv
	(a < b, mem1) |> (eval_arithm(a, mem1) < eval_arithm(b, mem1))
	(¬b, σ) |> !eval_bool(b, σ)
	(a ∨ b, σ) => (a, σ) ∨ (b, σ)
	(a ∧ b, σ) => (a, σ) ∧ (b, σ)
end

eval_bool(ex, mem) = 
	strategy(bool_rules)(:($ex, $mem))

@testset "Booleans" begin
	@test false == eval_bool(:(false ∨ false), Mem())
	@test true == eval_bool(:((false ∨ false) ∨ ¬(false ∨ false)), Mem(:x => 2))
	@test true == eval_bool(:((2 < 3) ∧ (3 < 4)), Mem(:x => 2))
	@test false == eval_bool(:((2 < x) ∨ ¬(3 < 4)), Mem(:x => 2))
	@test true == eval_bool(:((2 < x) ∨ ¬(3 < 4)), Mem(:x => 4))
end

if_rules = @theory begin
	(if guard; t end, σ) => (if guard; t else :skip end, σ)
	(if guard; t else f end, σ) |>
		(eval_bool(guard, σ) ? :($t, $σ) : :($f, $σ))
end

eval_if(ex::Expr, mem::Mem) = 
	strategy(read_mem ∪ arithm_rules ∪ if_rules)(:($ex, $mem))

@testset "If Semantics" begin
	@test 2 == eval_if(:(if true x else 0 end), Mem(:x => 2))
	@test 0 == eval_if(:(if false x else 0 end), Mem(:x => 2))
	@test 2 == eval_if(:(if ¬(false) x else 0 end), Mem(:x => 2))
	@test 0 == eval_if(:(if ¬(2 < x) x else 0 end), Mem(:x => 3))
end

while_rules = @theory begin
	(:skip, σ) => σ
	((:skip; c2), σ) => (c2, σ)
	((c1; c2), σ) |> begin
		r = eval_while(c1, σ);
		(r isa Mem) ? :($c2, $r) : :($c2, $σ)
	end
	(while guard body end, σ) =>
		(if guard; (body; while guard body end) else :skip end, σ)
end


write_mem = @theory begin
	(sym::Symbol = val, memory) |>
		(memory[sym] = eval_arithm(val, memory); memory)
	# (println("BEFORE $memory"); memory[sym] = eval_arithm(val, memory); println("AFTER $memory"); memory)
end

while_language = write_mem ∪ read_mem ∪ arithm_rules ∪ if_rules ∪ while_rules;

eval_while(ex, mem) = 
	strategy(while_language)(:($ex, $mem))

# FIXME issue with threading?
@testset "While Semantics" begin
	# @test Mem(:x => 3) == eval_while(:((x = 3)), Mem(:x => 2))
	@test Mem(:x => 5) == eval_while( :(x = 4; x = x + 1) , Mem(:x => 3))
	@test Mem(:x => 4) == eval_while( :( if x < 10; x = x + 1 end  ) , Mem(:x => 3))
	# @test 10 == eval_while( :( while x < 10; x = x + 1 end ; x ) , Mem(:x => 3))
	# @test 50 == eval_while( :( while x < y; (x = x + 1; y = y - 1) end ; x ) , Mem(:x => 0, :y => 100))
end
