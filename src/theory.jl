include("rule.jl")

# Theories can just be vectors of rules!


#identity_axiom = :($(quot(dollar(:i))) => i) #Expr(:call, :(=>), dollar(:i), :i)

identity_axiom = Rule(:(), :(), :($(quot(dollar(:i))) => i), :($(quot(dollar(:i))) => i))

makeblock(t::Vector{Rule}) = block(map(x -> x.pattern, t)..., identity_axiom.pattern)

macro theory(e)
    e = rmlines(e)
    if isexpr(e, :block)
        Vector{Rule}(e.args .|> Rule)
    else
        error("theory is not in form begin a => b; ... end")
    end
end
