
#=
# Write a very tiny Turing Complete language in Julia. 

WHILE is a very tiny Turing Complete Programming Language defined by denotational semantics. 
Semantics come from the excellent
[course notes](http://pages.di.unipi.it/degano/ECC-uno.pdf) in *"Elements of computability and
complexity"*  by prof. [Pierpaolo Degano](http://pages.di.unipi.it/degano/). 

It is a toy C-like language used to explain the core concepts of computability and Turing-completeness.
The name WHILE, comes from the fact that the most complicated construct in the language is a WHILE loop.
The language supports:
* A variable-value memory that can be pre-defined for program input.
* Integer arithmetics.
* Boolean logic.
* Conditional if-then-else statement called `cond`.
* Running a command after another with `seq(c1,c2)`.
* Repeatedly applying a command `c` while a condition `g` holds with `loop(g,c)`.

This is enough to be Turing-complete!

We are going to implement this tiny imperative language with classical rewriting rules in [Metatheory.jl](https://github.com/JuliaSymbolics/Metatheory.jl/).
WHILE is implemented in around 55 readable lines of code, and reaches around 80 lines with tests. 

The goal of this tutorial is to show an implementation of a programming language interpreter that is very, very very close to the
simple theory used to describe it in a textbook. Each denotational semantics rule in the course notes is a Metatheory.jl rewrite rule, with a few extras and minor naming changes. 
The idea, is that Julia is a really valid didactical programming language! 

=#

# Let's load the Metatheory and Test packages.
using Test, Metatheory

# ## Memory
# The first thing that our programming language needs, is a model of the *computer memory*,
# that is going to hold the state of the programs. We define the type of
# WHILE's memory as a map from variables (Julia `Symbol`s) to actual values. 
# We want to keep things simple so in our toy programming language we are just going to use boolean or integer values. Surprisingly, we can still achieve turing completeness without having to introduce strings or any other complex data type.
# We are going to use the letter `σ` (sigma) to denote an actual value of type `Mem`, in simple words the state of a program in a given moment.   
# For example, if a `σ::Mem` holds the value `σ[:a] = 2`, this means that at that given moment, in our program 
# the variable `a` holds the value 2.

const WhileLangValue = Union{Bool,Int}
Mem = Dict{Symbol,WhileLangValue}

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
# If we have an integer and a memory state, we can just keep the integer
# The following rules are the first cases of recursion. 
# Given two expressions `a,b`, to know what's `a + b` in state `σ`, 
# we need to know first what `a` and `b` are in state σ 
# The last dynamic rules let us directly evaluate arithmetic operations.

arithm_rules = @theory a b n σ begin
  (n::Int, σ::Mem) --> n
  (a + b, σ::Mem) --> (a, σ) + (b, σ)
  (a * b, σ::Mem) --> (a, σ) * (b, σ)
  (a - b, σ::Mem) --> (a, σ) - (b, σ)
  (a::Int + b::Int) => a + b
  (a::Int * b::Int) => a * b
  (a::Int - b::Int) => a - b
end


# ## Evaluation strategy
# We now have some nice denotational semantic rules for arithmetics, but in what order should we apply them?
# Metatheory.jl provides a flexible rewriter combinator library. You can read more in the [Rewriters](@ref) module docs. 
#
# Given a set of rules, we can define  a rewriter strategy by functionally composing rewriters.
# First, we want to use `Chain` to combine together the many rules in the theory, and to try to apply them one-by-one on our expressions.
#
# But should we first evaluate the outermost operations in the expression, or the innermost?
# Intuitively, if we have the program `(1 + 2) - 3`, it can hint us that we do want to first evaluate the innermost expressions.
# To do so, we then pass the result to the [Postwalk](@ref) rewriter, which recursively walks the input expression tree, and applies the rewriter first on 
# the inner expressions, and then, on the outer, rewritten expression. (Hence the name `Post`-walk. Can you guess what [Prewalk](@ref) does?).
#
# The last component of our strategy is the [Fixpoint](@ref) combinator. This combinator repeatedly applies the rewriter on the input expression,
# and it does stop looping only when the output expression is the unchanged input expression.

using Metatheory.Rewriters
strategy = (Fixpoint ∘ Postwalk ∘ Chain)

# In Metatheory.jl, rewrite theories are just vectors of [Rules](@ref). It means we can compose them by concatenating the vectors, or elegantly using the 
# built-in set operations provided by the Julia language.
arithm_lang = read_mem ∪ arithm_rules

# We can define a convenience function that takes an expression, a memory state and calls our strategy.
eval_arithm(ex, mem) = strategy(arithm_lang)(:($ex, $mem))


# Does it work?
@test eval_arithm(:(2 + 3), Mem()) == 5

# Yay! Let's say that before the program started, the computer memory already held a variable `x` with value 2.
@test eval_arithm(:(2 + x), Mem(:x => 2)) == 4


# ## Boolean Logic
# To be Turing-complete, our tiny WHILE language requires boolean logic support.
# There's nothing special or different from other programming languages. These rules 
# define boolean operations to work just as you would expect, and in the same way we defined arithmetic rules for integers.
# 
# We need to bridge together the world of integer arithmetics and boolean logic to achieve something useful.
# The last two rules in the theory.

bool_rules = @theory a b σ begin
  (a::Bool || b::Bool) => (a || b)
  (a::Bool && b::Bool) => (a && b)
  !a::Bool => !a
  (a::Bool, σ::Mem) => a
  (!b, σ::Mem) => !eval_bool(b, σ)
  (a || b, σ::Mem) --> (a, σ) || (b, σ)
  (a && b, σ::Mem) --> (a, σ) && (b, σ)
  (a < b, σ::Mem) => (eval_arithm(a, σ) < eval_arithm(b, σ)) # This rule bridges together ints and bools
  (a::Int < b::Int) => (a < b)
end

eval_bool(ex, mem) = strategy(bool_rules)(:($ex, $mem))

# Let's run a few tests.
@test all(
  [
    eval_bool(:(false || false), Mem()) == false
    eval_bool(:((false || false) || !(false || false)), Mem(:x => 2)) == true
    eval_bool(:((2 < 3) && (3 < 4)), Mem(:x => 2)) == true
    eval_bool(:((2 < x) || !(3 < 4)), Mem(:x => 2)) == false
    eval_bool(:((2 < x)), Mem(:x => 4)) == true
  ],
)

# ## Conditionals: If-then-else

# Conditional expressions in our language take the form of 
# `cond(guard, thenbranch)` or `cond(guard, branch, elsebranch)`
# It means that our program at this point will: 
# 1. Evaluate the `guard` expressions
# 2. If `guard` evaluates to `true`, then evaluate `thenbranch`
# 3. If `guard` evaluates to `false`, then evaluate `elsebranch`

# The first rule here is simple. If there's no `elsebranch` in the 
# `cond` statement, we add an empty one with the `skip` command. 
# Otherwise, we piggyback on the existing Julia if-then-else ternary operator.
# To do so, we need to evaluate the boolean expression in the guard by 
# using the `eval_bool` function we defined above.
if_rules = @theory guard t f σ begin
  (cond(guard, t), σ::Mem) --> (cond(guard, t, :skip), σ)
  (cond(guard, t, f), σ::Mem) => (eval_bool(guard, σ) ? :($t, $σ) : :($f, $σ))
end

eval_if(ex, mem::Mem) = strategy(read_mem ∪ arithm_rules ∪ if_rules)(:($ex, $mem))

# And here is our working conditional

@testset "If Semantics" begin
  @test 2 == eval_if(:(cond(true, x, 0)), Mem(:x => 2))
  @test 0 == eval_if(:(cond(false, x, 0)), Mem(:x => 2))
  @test 2 == eval_if(:(cond(!(false), x, 0)), Mem(:x => 2))
  @test 0 == eval_if(:(cond(!(2 < x), x, 0)), Mem(:x => 3))
end


# ## Writing memory

# Our language then needs a mechanism to write in memory. 
# We define the behavior of the `store` construct, which 
# behaves like the `=` assignment operator in other programming languages. 
# `store(a, 5)` will store the value 5 in the `a` variable inside the program's memory.

write_mem = @theory sym val σ begin
  (store(sym::Symbol, val), σ) => (σ[sym] = eval_if(val, σ);
  σ)
end

# ## While loops and sequential computation.

while_rules = @theory guard a b σ begin
  (:skip, σ::Mem) --> σ
  ((:skip; b), σ::Mem) --> (b, σ)
  (seq(a, b), σ::Mem) --> (b, merge((a, σ), σ))
  merge(a::Mem, σ::Mem) => merge(σ, a)
  merge(a::WhileLangValue, σ::Mem) --> σ
  (loop(guard, a), σ::Mem) --> (cond(guard, seq(a, loop(guard, a)), :skip), σ)
end


# ## Completing the language.

while_language = write_mem ∪ read_mem ∪ arithm_rules ∪ if_rules ∪ while_rules;

using Metatheory.Syntax: rmlines
eval_while(ex, mem) = strategy(while_language)(:($(rmlines(ex)), $mem))

# Final steps

@testset "While Semantics" begin
  @test Mem(:x => 3) == eval_while(:((store(x, 3))), Mem(:x => 2))
  @test Mem(:x => 5) == eval_while(:(seq(store(x, 4), store(x, x + 1))), Mem(:x => 3))
  @test Mem(:x => 4) == eval_while(:(cond(x < 10, store(x, x + 1))), Mem(:x => 3))
  @test 10 == eval_while(:(seq(loop(x < 10, store(x, x + 1)), x)), Mem(:x => 3))
  @test 50 == eval_while(:(seq(loop(x < y, seq(store(x, x + 1), store(y, y - 1))), x)), Mem(:x => 0, :y => 100))
end
