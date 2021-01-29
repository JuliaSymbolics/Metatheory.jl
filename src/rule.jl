## Rules

struct Rule
    left::Any
    right::Any
    expr::Expr # original expression
    mode::Symbol # can be :rewrite or :dynamic
end

# operator symbols for simple term rewriting
const rewrite_syms = [:(=>), :(⇒), :(⟹), :(⤇), :(⟾)]
# operator symbols for regular pattern matching rules, "dynamic rules"
# that eval the right side at reduction time.
# might be used to implement big step semantics
const dynamic_syms = [:(|>)]

function Rule(e::Expr)
    mode = :undef
    if isexpr(e, :call)
        mode = e.args[1]
        l = e.args[2]
        r = e.args[3]
    else
        mode = e.head
        l = e.args[1]
        r = e.args[2]
    end

    if mode ∈ dynamic_syms # right hand execution, dynamic rules in egg
        mode = :dynamic
    elseif mode ∈ rewrite_syms # right side is quoted, symbolic replacement
        mode = :rewrite
    else
        error(`rule "$e" is not in valid form.\n`)
    end

    Rule(l, r, e, mode)
end

macro rule(e)
    Rule(e)
end

# string representation of the rule
function Base.show(io::IO, x::Rule)
    println(io, "Rule(:(", x.expr, "))")
end
