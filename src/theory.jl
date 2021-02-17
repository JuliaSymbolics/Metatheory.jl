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
