using MLStyle

## DONE handle type assertions, they are supported in MLStyle
# TODO consider, equivalence classes (uniondisjoint union-find),
# egraphs, equality saturation

## Utility functions

# Remove LineNumberNode from quoted blocks of code
rmlines(e::Expr) = Expr(e.head, filter(!isnothing, map(rmlines, e.args))...)
rmlines(a) = a
rmlines(x::LineNumberNode) = nothing
macro rmlines(x) rmlines(x) end

# useful shortcuts for nested macros
dollar(v) = Expr(:$, v)
block(vs...) = Expr(:block, vs...)
amp(v) = Expr(:&, v)

# meta shortcuts for readability
quot = Meta.quot
isexpr = Meta.isexpr

# don't compile those particular expression
dont_touch(e) = isexpr(e, :(::)) ||  isexpr(e, :(...))

function walk_lit_nofun(f, e::Expr, f_args...)
    # leave type asserts as they are
    if dont_touch(e)
        return e
    end
    # avod calling on function names! FUNDAMENTAL
    start = isexpr(e, :call) ? 2 : 1
    e.args[start:end] =  e.args[start:end] .|> x -> f(x, f_args...)
    return e
end

# allows functions
function walk_lit(f, e::Expr, f_args...)
    # leave type asserts as they are
    if dont_touch(e)
        return e
    end
    e.args =  e.args .|> x -> f(x, f_args...)
    return e
end


## compile (quote) left and right hands of a rule
# escape symbols to create MLStyle compatible patterns

# compile left hand of rule
c_left(e::Expr, s::Set) = walk_lit_nofun(c_left, e, s)
# if it's the first time seeing v, add it to the "seen symbols" Set
# insert a :& expression only if v has not been seen before
c_left(v::Symbol, s) = (v ∉ s ? (push!(s,v); v) : amp(v)) |> dollar
c_left(v, s) = v # ignore other types

c_right(e::Expr) = walk_lit_nofun(c_right, e)
c_right(v::Symbol) = dollar(v)
c_right(v) = v #ignore other types



## Rule

struct Rule
    left
    right
    pattern::Expr # compiled for MLStyle @matchast
end

function Rule(e::Expr)
    if !isexpr(e, :call) error(`rule $e not in form a =\> b\n`) end
    mode = e.args[1]
    l = e.args[2]
    r = e.args[3]

    le = c_left(l,  Set{Symbol}()) |> quot
    # no escape mode! Yay!
    if mode == :(↦)
        re = r
    elseif mode == :(=>)
        re = c_right(r) |> quot
    else
        error(`rule $e not in form a =\> b\n`)
    end

    Rule(l,r, :($le => $re))
end

macro rule(e)
    Rule(e)
end

## Theories

struct Theory
    rules::Set{Rule}
    patternblock::Expr
end

function Theory(rs::Rule...)
    Theory(Set(rs), block(map(x -> x.pattern, rs)...))
end

# extend a theory with a rule
function Base.push!(t::Theory, r::Rule)
    push!(t.rules, r)
    push!(t.patternblock.args, r.pattern)
end

# can add "invisible" rules to a theory
function Base.push!(t::Theory, r::Expr)
    push!(t.patternblock.args, r)
end

identity_axiom = :($(quot(dollar(:i))) => i) #Expr(:call, :(=>), dollar(:i), :i)

macro theory(e)
    e = rmlines(e)
    if isexpr(e, :block)
        t = Theory(Rule.(e.args)...)
        push!(t, identity_axiom)
        t
    else
        error("theory is not in form begin a => b; ... end")
    end
end

## Reduction

function reduce_step(ex, block, __source__::LineNumberNode, __module__::Module)
    res = MatchCore.gen_match(ex, block, __source__, __module__)
    #println(res)
    res = MatchCore.AbstractPatterns.init_cfg(res)
    res
end

# key algorithm of Metatheory :)
function reduce_loop(ex, t, __source__::LineNumberNode, __module__::Module)
    #@info :call_on ex
    old = ex
    new = reduce_step(ex, t, __source__, __module__) |> eval

    # try to see big picture patterns first
    while new != old
        old = new
        new = reduce_step(quot(old), t, __source__, __module__) |> eval
        println(new)
        #return
    end

    #elseif isexpr(e, :call) && foldl((x,y) -> x&&(y isa Number), e.args[2,end])
    # if e is an expression with only numeric children

    # new == old TIME TO RECURSE!
    if isexpr(new, :call)
        old = copy(new)
        new.args[2:end] = map(x -> reduce_loop(quot(x), t, __source__, __module__) |> eval, new.args[2:end])
    end

    while new != old
        old = new
        new = reduce_loop(quot(old), t, __source__, __module__) |> eval
        #return
    end

    #@warn :result new
    new |> quot
end


macro reduce(ex, theory)
    t = eval(theory)
    old = ex
    reduce_loop(quot(ex), t.patternblock, __source__, __module__)
end


# basic theory to check that everything works
t = @theory begin
   a + a => 2a
   x/x => 1
   x * 1 => x
end;

# Let's build a more complex theory from basic calculus facts
t = @theory begin
    f(x) => 42
    !a => f(x)
    a + a => 2a
    a * a => a^2
    x/x => 1

    

    # maps
    $(a::Number) * $(b::Number) ↦ a*b
    $(a::Number) + $(b::Number) ↦ a+b

    # Associativity of * on numbers
    $(a::Number) * ($(b::Number) * c) ↦ :($(a*b) * $c)
    $(a::Number) * (c * $(b::Number)) ↦ :($(a*b) * $c)

    a + $(b::Number) * a ↦ :($(b+1) * $a)
    $(b::Number) * a + a ↦ :($(b+1) * $a)
end

t = @theory begin
    &x => x
end

@reduce (x+x) * (3/3) + (y+y) t


#TODO binarize AST when passing to reduce_step, if theory contains a list of binop symbols
