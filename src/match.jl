# regular, old school pattern matching
include("./reduce.jl")

macro matcher(te)
    if Meta.isexpr(te, :block) # @matcher begine rules... end
		te = rmlines(te)
        t = compile_theory(Vector{Rule}(te.args .|> Rule), __module__)
    else
        if !isdefined(__module__, te) error(`theory $theory not found!`) end
        t = getfield(__module__, te)
		if t isa Vector{Rule}; t = compile_theory(t, __module__) end
        if !t isa Function error(`$te is not a valid theory`) end
    end

	quote (x) -> ($t)(x, $__module__) end
end
