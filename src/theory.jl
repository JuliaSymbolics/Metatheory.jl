include("rule.jl")

# Theories can just be vectors of rules!

makeblock(t::Vector{Rule}) = block(map(x -> x.pattern, t)...)

#identity_axiom = :($(quot(dollar(:i))) => i) #Expr(:call, :(=>), dollar(:i), :i)

identity_axiom = Rule(:(), :(), :($(quot(dollar(:i))) => i), :($(quot(dollar(:i))) => i))

macro theory(e)
    e = rmlines(e)
    if isexpr(e, :block)
        t = Vector{Rule}(e.args .|> Rule)
        push!(t, identity_axiom)
        t
    else
        error("theory is not in form begin a => b; ... end")
    end
end
