include("rule.jl")

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

function Base.show(io::IO, x::Theory)
    println(io, "(theory with ", length(x.rules), " rules)")
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
