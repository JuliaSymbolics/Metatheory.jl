# regular, old school pattern matching

macro matcher(te)
    if Meta.isexpr(te, :block) # @matcher begine rules... end
		te = rmlines(te)
        t = gettheoryfun(Vector{AbstractRule}(te.args .|> Rule), __module__)
    else
        if !isdefined(__module__, te) error(`theory $theory not found!`) end
        t = getfield(__module__, te)
		if t isa Vector{<:AbstractRule}; t = compile_theory(t, __module__) end
        if !t isa Function error(`$te is not a valid theory`) end
    end

	t
	# quote (x) -> ($t)(x) end
end
