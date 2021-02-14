
## Turing Complete Interpreter
### A Very Tiny Turing Complete Programming Language defined with denotational semantics

# semantica dalle dispense degano

Mem = Dict{Symbol, Union{Bool, Int}}

read_mem = @theory begin
	(v::Symbol, mem) |> mem[v]
end

@testset "Reading Memory" begin
	@test 2 == rewrite(:((x), $(Mem(:x => 2))), read_mem; order=:inner)#, m=@__MODULE__)
	# if the last arg is uncommented, and
	# include("test_theories.jl")
	# include("test_reductions.jl")
	# are commented in "test/runtests.jl"

	# this happens

	# TODO report issue to RuntimeGeneratedFunctions.jl
	# Reading Memory: Error During Test at /home/sea/src/julia/Metatheory/test/test_while_interpreter.jl:17
	#   Test threw exception
	#   Expression: 2 == rewrite(:((x, $(Mem(:x => 2)))), read_mem; order = :inner, m = #= /home/sea/src/julia/Metatheory/test/test_while_interpreter.jl:17 =# @__MODULE__())
	#   MethodError: no method matching generated_callfunc(::RuntimeGeneratedFunctions.RuntimeGeneratedFunction{(Symbol("##reducing_expression#257"),), var"#_RGF_ModTag", var"#_RGF_ModTag", (0xa3a3c3bf, 0xb070e435, 0x08893b98, 0x9f9e31fb, 0xf15bd3ff)}, ::Symbol, ::Module)
	#   The applicable method may be too new: running in world age 29639, while current world is 29642.
	#   Closest candidates are:
	#     generated_callfunc(::RuntimeGeneratedFunctions.RuntimeGeneratedFunction{argnames, cache_tag, var"#_RGF_ModTag", id}, ::Any...) where {argnames, cache_tag, id} at none:0 (method too new to be called from this world context.)
	#     generated_callfunc(::RuntimeGeneratedFunctions.RuntimeGeneratedFunction{argnames, cache_tag, Metatheory.var"#_RGF_ModTag", id}, ::Any...) where {argnames, cache_tag, id} at none:0
	#   Stacktrace:
	#     [1] (::RuntimeGeneratedFunctions.RuntimeGeneratedFunction{(Symbol("##reducing_expression#257"),), var"#_RGF_ModTag", var"#_RGF_ModTag", (0xa3a3c3bf, 0xb070e435, 0x08893b98, 0x9f9e31fb, 0xf15bd3ff)})(::Symbol, ::Module)
	#       @ RuntimeGeneratedFunctions ~/.julia/packages/RuntimeGeneratedFunctions/tJEmP/src/RuntimeGeneratedFunctions.jl:92
	#     [2] (::Metatheory.var"#35#41"{Module})(x::Symbol)
	#       @ Metatheory ~/src/julia/Metatheory/src/rewrite.jl:24
	#     [3] normalize_nocycle(::Function, ::Symbol; callback::Metatheory.var"#34#40"{Int64})
	#       @ Metatheory ~/src/julia/Metatheory/src/util.jl:119
	#     [4] #36
	#       @ ~/src/julia/Metatheory/src/rewrite.jl:25 [inlined]
	#     [5] #df_walk!#6
	#       @ ~/src/julia/Metatheory/src/util.jl:30 [inlined]
	#     [6] #7
	#       @ ~/src/julia/Metatheory/src/util.jl:38 [inlined]
	#     [7] |>(x::Symbol, f::Metatheory.var"#7#8"{Vector{Symbol}, Bool, Metatheory.var"#36#42"{Metatheory.var"#35#41"{Module}, Metatheory.var"#34#40"{Int64}}, Tuple{}})
	#       @ Base ./operators.jl:859
	#     [8] _broadcast_getindex_evalf
	#       @ ./broadcast.jl:648 [inlined]
	#     [9] _broadcast_getindex
	#       @ ./broadcast.jl:621 [inlined]
	#    [10] getindex
	#       @ ./broadcast.jl:575 [inlined]
	#    [11] copy
	#       @ ./broadcast.jl:922 [inlined]
	#    [12] materialize(bc::Base.Broadcast.Broadcasted{Base.Broadcast.DefaultArrayStyle{1}, Nothing, typeof(|>), Tuple{Vector{Any}, Base.RefValue{Metatheory.var"#7#8"{Vector{Symbol}, Bool, Metatheory.var"#36#42"{Metatheory.var"#35#41"{Module}, Metatheory.var"#34#40"{Int64}}, Tuple{}}}}})
	#       @ Base.Broadcast ./broadcast.jl:883
	#    [13] df_walk!(::Function, ::Expr; skip::Vector{Symbol}, skip_call::Bool)
	#       @ Metatheory ~/src/julia/Metatheory/src/util.jl:38
	#    [14] #37
	#       @ ~/src/julia/Metatheory/src/rewrite.jl:30 [inlined]
	#    [15] (::Metatheory.var"#39#45"{Metatheory.var"#37#43", Metatheory.var"#36#42"{Metatheory.var"#35#41"{Module}, Metatheory.var"#34#40"{Int64}}})(x::Expr)
	#       @ Metatheory ~/src/julia/Metatheory/src/rewrite.jl:37
	#    [16] normalize_nocycle(::Function, ::Expr; callback::Metatheory.var"#24#26")
	#       @ Metatheory ~/src/julia/Metatheory/src/util.jl:119
	#    [17] normalize_nocycle(::Function, ::Expr)
	#       @ Metatheory ~/src/julia/Metatheory/src/util.jl:117
	#    [18] rewrite(ex::Expr, theory::Vector{Rule}; __source__::LineNumberNode, order::Symbol, m::Module, timeout::Int64)
	#       @ Metatheory ~/src/julia/Metatheory/src/rewrite.jl:37
	#    [19] macro expansion
	#       @ ~/src/julia/Metatheory/test/test_while_interpreter.jl:17 [inlined]
	#    [20] macro expansion
	#       @ ~/src/julia-compiler/usr/share/julia/stdlib/v1.6/Test/src/Test.jl:1151 [inlined]
	#    [21] top-level scope
	#       @ ~/src/julia/Metatheory/test/test_while_interpreter.jl:17
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

eval_arithm(ex, mem) = (@rewriter(read_mem ∪ arithm_rules, :inner))(:($ex, $mem))


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

eval_bool(ex, mem) = (@rewriter(bool_rules, :inner))(:($ex, $mem))

@testset "Booleans" begin
	@test false == eval_bool(:(false ∨ false), Mem())
	@test true == eval_bool(:((false ∨ false) ∨ ¬(false ∨ false)), Mem(:x => 2))
	@test true == eval_bool(:((2 < 3) ∧ (3 < 4)), Mem(:x => 2))
	@test false == eval_bool(:((2 < x) ∨ ¬(3 < 4)), Mem(:x => 2))
	@test true == eval_bool(:((2 < x) ∨ ¬(3 < 4)), Mem(:x => 4))
end

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
