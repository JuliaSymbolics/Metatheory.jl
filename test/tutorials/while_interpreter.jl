
#=
# Writing a tiny, readable Turing Complete programming language in Julia. 

WHILE is a very tiny Turing Complete Programming Language defined with denotational semantics. 
Semantics come from the excellent
[course notes](http://pages.di.unipi.it/degano/ECC-uno.pdf) in *"Elements of computability and
complexity"*  by prof. [Pierpaolo Degano](http://pages.di.unipi.it/degano/). 

We are going to implement this tiny imperative language with classical rewriting rules in [Metatheory.jl](https://github.com/JuliaSymbolics/Metatheory.jl/).

The goal of this tutorial is to show an implementation of a programming language interpreter that is:
* Imperative, using simple control flow and loops. (`if-then-else` and `while`). 
* Is very, very very close to the theory. Each denotational semantics rule in the notes is a Metatheory.jl rewrite rule. 
* Concise, but still yielding educational content. WHILE is implemented in around 70 readable lines of code, and reaches 120 lines with tests.  
=#

using Test
using Metatheory
using Metatheory.Rewriters


# ## Memory
# The first thing that our programming language needs, is a model of the *computer memory*,
# that is going to hold the state of the programs. We define the type of
# WHILE's memory as a map from variables (Julia `Symbol`s) to actual values. 
# We want to keep things simple so in our toy programming language we are just going to use boolean or integer values. Surprisingly, we can still achieve turing completeness without having to introduce strings or any other complex data type.
# We are going to use the letter `σ` (sigma) to denote an actual value of type `Mem`, in simple words the state of a program in a given moment.   
# For example, if a `σ::Mem` holds the value `σ[:a] = 2`, this means that at that given moment, in our program 
# the variable `a` holds the value 2.

Mem = Dict{Symbol,Union{Bool,Int}}

# We are now ready to define our first rewrite rule. 
# In WHILE, un-evaluated expressions are represented by a tuple of `(program, state)`. 
# This simple rule tells us that, if at a given memory state `σ` we want to know the value of a variable `v`, we 
# can simply read it from the memory and return the value. 
read_mem = @theory v σ begin
  (v::Symbol, σ::Mem) => σ[v]
end

# Let's test this behavior. We first create a `Mem`, holding the variable `x` with value 2. 
σ₁ = Mem(:x => 2)

# Then, we define a program. Julia helps us avoid unneeded complications. 
# Generally, to create an interpreted programming language, one would have to design a syntax for it, and then engineer components such as 
# a lexer or a [parser](https://en.wikipedia.org/wiki/Parsing) in order to turn the input string into a manipulable, structured program. 
# The Julia developers were really smart. We can directly re-use the whole Julia syntax, because Julia 
# allows us to treat programs as values. You can try this by prefixing any expression you type in the REPL inside of `:( ... )` or `quote ... end`. 
# If you type this in the Julia REPL: 
2 + 2

# You get the obvious result out, but if you wrap it in `quote` or `:(...)`, you can see that the program will not be executed, but instead stored as an `Expr`.
some_expr = :(2 + 2)
dump(some_expr)

# We can use the `$` unary operator to interpolate and insert values inside of quoted code.
:(2 + $(1 + 1))

# These code-manipulation utilities can be very useful, because we can completely skip the burden of having to write a new syntax for our educational programming language, and just 
# re-use Julia's syntax. It hints us that Julia is very powerful, because you can define new semantics and customize the language's behaviour without 
# having to leave the comfort of the Julia terminal. This is also how julia `@macros` work.  
# The practice of manipulating programs in the language itself is called **Metaprogramming**,  
# and you can read more about metaprogramming in Julia [in the official docs](https://docs.julialang.org/en/v1/manual/metaprogramming/).


# Let's test that our first, simple rule is working. 
program = :(x, $σ₁)
@test rewrite(program, read_mem) == 2

# ## Arithmetics
# How can our programming language be turing complete if we do not include basic arithmetics?
arithm_rules = @theory a b n σ begin
  (n::Int, σ::Mem) => n
  (a + b, σ::Mem) --> (a, σ) + (b, σ)
  (a * b, σ::Mem) --> (a, σ) * (b, σ)
  (a - b, σ::Mem) --> (a, σ) - (b, σ)
  (a::Int + b::Int) => a + b
  (a::Int * b::Int) => a * b
  (a::Int - b::Int) => a - b
end

strategy = (Fixpoint ∘ Postwalk ∘ Chain)

eval_arithm(ex, mem) = strategy(read_mem ∪ arithm_rules)(:($ex, $mem))


@testset "Arithmetic" begin
  @test 5 == eval_arithm(:(2 + 3), Mem())
  @test 4 == eval_arithm(:(2 + x), Mem(:x => 2))
end

# don't need to access memory
bool_rules = @theory a b σ begin
  (a::Bool || b::Bool) => (a || b)
  (a::Bool && b::Bool) => (a && b)
  (a::Int < b::Int) => (a < b)
  !a::Bool => !a
  (a::Bool, σ::Mem) => a
  (a < b, σ::Mem) => (eval_arithm(a, σ) < eval_arithm(b, σ))
  (!b, σ::Mem) => !eval_bool(b, σ)
  (a || b, σ::Mem) --> (a, σ) || (b, σ)
  (a && b, σ::Mem) --> (a, σ) && (b, σ)
end

eval_bool(ex, mem) = strategy(bool_rules)(:($ex, $mem))

@testset "Booleans" begin
  @test false == eval_bool(:(false || false), Mem())
  @test true == eval_bool(:((false || false) || !(false || false)), Mem(:x => 2))
  @test true == eval_bool(:((2 < 3) && (3 < 4)), Mem(:x => 2))
  @test false == eval_bool(:((2 < x) || !(3 < 4)), Mem(:x => 2))
  @test true == eval_bool(:((2 < x) || !(3 < 4)), Mem(:x => 4))
end

function cond end

if_rules = @theory guard t f σ begin
  (cond(guard, t), σ::Mem) --> (cond(guard, t, :skip), σ)
  (cond(guard, t, f), σ::Mem) => (eval_bool(guard, σ) ? :($t, $σ) : :($f, $σ))
end

eval_if(ex::Expr, mem::Mem) = strategy(read_mem ∪ arithm_rules ∪ if_rules)(:($ex, $mem))

@testset "If Semantics" begin
  @test 2 == eval_if(:(cond(true, x, 0)), Mem(:x => 2))
  @test 0 == eval_if(:(cond(false, x, 0)), Mem(:x => 2))
  @test 2 == eval_if(:(cond(!(false), x, 0)), Mem(:x => 2))
  @test 0 == eval_if(:(cond(!(2 < x), x, 0)), Mem(:x => 3))
end

function seq end
function loop end

while_rules = @theory guard a b σ begin
  (:skip, σ::Mem) --> σ
  ((:skip; b), σ::Mem) --> (b, σ)
  (seq(a, b), σ::Mem) --> (b, merge((a, σ), σ))
  merge(a::Mem, σ::Mem) => merge(σ, a)
  merge(a::Union{Bool,Int}, σ::Mem) --> σ
  (loop(guard, a), σ::Mem) --> (cond(guard, seq(a, loop(guard, a)), :skip), σ)
end

function assign end

write_mem = @theory sym val σ begin
  (assign(sym::Symbol, val), σ) => (σ[sym] = eval_arithm(val, σ);
  σ)
end

while_language = write_mem ∪ read_mem ∪ arithm_rules ∪ if_rules ∪ while_rules;

using Metatheory.Syntax: rmlines
eval_while(ex, mem) = strategy(while_language)(:($(rmlines(ex)), $mem))

@testset "While Semantics" begin
  @test Mem(:x => 3) == eval_while(:((assign(x, 3))), Mem(:x => 2))
  @test Mem(:x => 5) == eval_while(:(seq(assign(x, 4), assign(x, x + 1))), Mem(:x => 3))
  @test Mem(:x => 4) == eval_while(:(cond(x < 10, assign(x, x + 1))), Mem(:x => 3))
  @test 10 == eval_while(:(seq(loop(x < 10, assign(x, x + 1)), x)), Mem(:x => 3))
  @test 50 == eval_while(:(seq(loop(x < y, seq(assign(x, x + 1), assign(y, y - 1))), x)), Mem(:x => 0, :y => 100))
end
