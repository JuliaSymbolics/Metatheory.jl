
## Turing Complete Interpreter
### A Very Tiny Turing Complete Programming Language defined with denotational semantics

# semantica dalle dispense degano

const Mem = Base.ImmutableDict{Symbol, Union{Bool, Int}}

read_mem = @theory begin
	(v::Symbol, σ::Mem) |> σ[v]
end

@testset "Reading Memory" begin
	@test true == areequal(read_mem, :((x), $(Mem(:x, 2))), 2, mod=@__MODULE__)
end

arithm_rules = @theory begin
	(a + b, σ) 		  	=> (a, σ) + (b, σ)
	(a * b, σ) 		  	=> (a, σ) * (b, σ)
	(a - b, σ) 		  	=> (a, σ) - (b, σ)
	(n::Int, σ) 		=> n
	(a::Int + b::Int) 	|> a + b
	(a::Int * b::Int) 	|> a * b
	(a::Int - b::Int) 	|> a - b
end


@testset "Arithmetic" begin
	@test areequal(read_mem ∪ arithm_rules,
		:((2 + 3), $(Mem())), 5, mod=@__MODULE__)
	@test areequal(read_mem ∪ arithm_rules,
		:((2 + x), 4; mod=@__MODULE__))
end

# don't need to access memory
bool_rules = @theory begin
	(a::Bool ∨ b::Bool, σ) 	|> (a || b)
	(a::Bool ∧ b::Bool, σ) 	|> (a && b)
	(a::Bool ∨ b::Bool) 	|> (a || b)
	(a::Bool ∧ b::Bool) 	|> (a && b)
	(a::Bool, σ) 			|> a
	(¬a::Bool, σ) 			|> !a
	¬a::Bool 				|> !a
	(a::Int < b::Int, σ) |> (a < b)
	(a::Int < b::Int) 	 |> (a < b)
	¬(a, σ) => (¬a, σ)

	# (¬b, σ) |> !eval_bool(b, σ)
	(a < b, σ) => (a, σ) < (b, σ)
	(a ∨ b, σ) => (a, σ) ∨ (b, σ)
	(a ∧ b, σ) => (a, σ) ∧ (b, σ)
end

t = read_mem ∪ arithm_rules ∪ bool_rules

@testset "Booleans" begin
	@test areequal(t, :((false ∨ false), $(Mem())),
		false; mod=@__MODULE__)
	@test areequal(t, :((false ∨ false) ∨ ¬(false ∨ false), $(Mem(:x, 2))),
		true; mod=@__MODULE__)
	@test areequal(t, :((2 < 3) ∧ (3 < 4), $(Mem(:x, 2))),
		true; mod=@__MODULE__)
	@test areequal(t, :((2 < x) ∨ ¬(3 < 4), $(Mem(:x, 2))),
		false; mod=@__MODULE__)
	@test  areequal(t, :((2 < x) ∨ ¬(3 < 4), $(Mem(:x, 4))),
		true; mod=@__MODULE__)
end

exit(0)

if_rules = @theory begin
	(if guard; t end, σ) => (if guard; t else skip end, σ)
	(if guard; t else f end, σ) |>
		(eval_bool(guard, σ) ? :($t, $σ) : :($f, $σ))
end

eval_if(ex::Expr, mem::Mem) = (@rewriter(read_mem ∪ arithm_rules ∪ if_rules, :inner))(:($ex, $mem))

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
		(if guard; (body; while guard body end) else skip end, σ)
end


write_mem = @theory begin
	(sym::Symbol = val, memory) |>
		(memory[sym] = eval_arithm(val, memory); memory)
end

while_language = @compile_theory write_mem ∪ read_mem ∪ arithm_rules ∪ if_rules ∪ while_rules;

eval_while(ex, mem) = (@rewriter(while_language, :inner))(:($ex, $mem))

@testset "While Semantics" begin
	@test Mem(:x => 3) == eval_while(:((x = 3)), Mem(:x => 2))
	@test Mem(:x => 5) == eval_while( :(x = 4; x = x + 1) , Mem(:x => 3))
	@test Mem(:x => 4) == eval_while( :( if x < 10; x = x + 1 end  ) , Mem(:x => 3))
	@test 10 == eval_while( :( while x < 10; x = x + 1 end ; x ) , Mem(:x => 3))
	@test 50 == eval_while( :( while x < y; (x = x + 1; y = y - 1) end ; x ) , Mem(:x => 0, :y => 100))
end
