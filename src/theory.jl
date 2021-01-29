# Theories can just be vectors of rules!

macro theory(e)
    e = rmlines(e)
    if isexpr(e, :block)
        Vector{Rule}(e.args .|> Rule)
    else
        error("theory is not in form begin a => b; ... end")
    end
end

# Retrieve a theory from a module at compile time. Not exported
function gettheory(var, mod)
    if !isdefined(mod, var) error(`theory $theory not found!`) end
    t = getfield(mod, var)
    if !(t isa Vector{Rule}) error(`$theory is a $(typeof(theory)), not a Vector\{Rule\}`) end
    return t
end
