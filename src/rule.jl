include("util.jl")

## Rules

struct Rule
    left::Any
    right::Any
    pattern::Expr # compiled for MLStyle @matchast
end

## compile (quote) left and right hands of a rule
# escape symbols to create MLStyle compatible patterns

# compile left hand of rule
# if it's the first time seeing v, add it to the "seen symbols" Set
# insert a :& expression only if v has not been seen before
function c_left(v::Symbol, s)
    if Base.isbinaryoperator(v) return v end
    (v ∉ s ? (push!(s, v); v) : amp(v)) |> dollar
end
c_left(v::Expr, s) = v.head ∈ add_dollar ? dollar(v) : v
c_left(v, s) = v # ignore other types

c_right(v::Symbol) = Base.isbinaryoperator(v) ? v : dollar(v)
function c_right(v::Expr)
    println(dollar(v))
    v.head ∈ add_dollar ? dollar(v) : v
end
c_right(v) = v #ignore other types

# add dollar in front of the expressions with those symbols as head
add_dollar = [:(::), :(...)]

# don't walk down on these symbols
skips = [:(::), :(...)]

function Rule(e::Expr)
    if !isexpr(e, :call)
        error(`rule $e not in form a =\> b\n`)
    end
    mode = e.args[1]
    l = e.args[2]
    r = e.args[3]

    le = df_walk!(c_left, l, Set{Symbol}(); skip=skips, skip_call=true) |> quot
    #le = c_left(l, Set{Symbol}()) |> quot
    if mode == :(↦)
        re = r # right side not quoted! needed to evaluate expressions in subst.
    elseif mode == :(=>) # right side is quoted, symbolic replacement
        re = df_walk!(c_right, r; skip=skips, skip_call=true) |> quot
    else
        error(`rule $e not in form a =\> b\n`)
    end

    Rule(l, r, :($le => $re))
end

macro rule(e)
    Rule(e)
end
