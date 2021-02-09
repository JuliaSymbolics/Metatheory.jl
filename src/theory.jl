# Theories can just be vectors of rules!

macro theory(e)
    e = rmlines(e)
    if isexpr(e, :block)
        Vector{Rule}(e.args .|> Rule)
    else
        error("theory is not in form begin a => b; ... end")
    end
end

const Theory = Union{Vector{Rule}, Function}

# Retrieve a theory from a module at compile time. Not exported
function gettheory(var, mod; compile=true)
	t = nothing
    if Meta.isexpr(var, :block) # @matcher begine rules... end
		t = rmlines(var).args .|> Rule
	else
		t = mod.eval(var)
	end

	if compile && !(t isa Function)
		t = compile_theory(t, mod)
	end

	return t
end
