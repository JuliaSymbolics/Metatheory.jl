
<<<<<<< HEAD
# =============================================================
# ================== STAGED ===================================
# =============================================================

=======
>>>>>>> master
function next(p::Program, n, σ, pc)
    stage(p, p.instructions[pc+1], n, σ, pc+1)
end

function stage(p::Program, instr::Yield, n, σ, pc)
    quote
        sourcenode = $(n[p.first_nonground])
        ecs = [ $([σ[reg] for reg in instr.yields]...) ]
        nodes = [ $([n[reg] for reg in instr.yields]...) ]
        push!(_buf, Sub(sourcenode, ecs, nodes)) 
    end
end

function stage(p::Program, instr::CheckClassEq, n, σ, pc)
    quote
        l = $(σ[instr.left])
        r = $(σ[instr.right]) 
        if l == r 
            $(next(p, n, σ, pc))
        end
    end
end

function stage(p::Program, instr::CheckType, n, σ, pc)
    id = gensym(:id)
    eclass = gensym(:eclass)
    enode = gensym(:enode)
    quote
        $id = $(σ[instr.reg])
        $eclass = _egraph[$id]

        for $enode in $eclass 
            if arity($enode) == 0 && typeof($enode.head) <: $(instr.type)
                $(σ[instr.reg]) = $id
                $(n[instr.reg]) = $enode
                $(next(p, n, σ, pc))
            end
        end
    end
end

function stage(p::Program, instr::Lookup, n, σ, pc)
    ecid = gensym(:ecid)
    quote
        $ecid = lookup_pat(_egraph, $(instr.p))
        if $ecid isa EClassId
            # println("found $(instr.p) in $ecid")
            $(σ[instr.reg]) = $ecid
            $(next(p, n, σ, pc))
        end
    end
end


function stage(p::Program, instr::Bind, n, σ, pc)
    enode = gensym(:enode)
    quote
        ecid = $(σ[instr.reg])
        eclass = _egraph[ecid]
    
        for $enode in eclass.nodes
            if $enode.head == $(QuoteNode(instr.enodepat.head)) && length($enode.args) == $(length(instr.enodepat.args))
                $(n[instr.reg]) = $enode
                $(
                    begin
                        for (j,v) in enumerate(instr.enodepat.args)
                            σ[v] = :($enode.args[$j])
                        end
                        next(p, n, σ, pc) 
                    end
                )
            end
        end
    end
end

const Code = Union{Expr, Symbol}

function stage(p::Program)
    n = Code[gensym("node$i") for i in 1:p.memsize]
    σ = Code[gensym("reg$i") for i in 1:p.memsize]

    σ[p.first_nonground] = :_start

    staged_instructions = stage(p, p.instructions[1], n, σ, 1)
    
    :( (_egraph, _start) -> begin
            # initialize the registers 
            $(Expr(:block, [ :($(n[i]) = nothing) for i in 1:p.memsize]...))
            _buf = Sub[]
            $staged_instructions
            return _buf
        end
    )
<<<<<<< HEAD
end

# =============================================================


# Global Right Hand Side function cache for dynamic rules.
const EMATCH_STAGED_PROG_CACHE = IdDict{Pattern, Function}()
const EMATCH_STAGED_PROG_CACHE_LOCK = ReentrantLock()

# using MacroTools
function getstagedprogram(p::Pattern)
    lock(EMATCH_STAGED_PROG_CACHE_LOCK) do
        if !haskey(EMATCH_STAGED_PROG_CACHE, p)
            # println("cache miss!")
            program = compile_pat(p)
            program_expr = stage(program)
            # println(prettify(program_expr))
            # mod = @__MODULE__
            f = eval(program_expr)
            # f = closure_generator(@__MODULE__, program_expr)
            EMATCH_STAGED_PROG_CACHE[p] = f
            return f
        end
        return EMATCH_STAGED_PROG_CACHE[p]
    end
end

function ematch(g::EGraph, p::Pattern, eclass::EClassId)
    # program = getprogram(p)
    f = getstagedprogram(p)
    return Base.invokelatest(f, g, eclass)
end

# no compile time with staged and RGF for tests
# 35.020147 seconds (97.38 M allocations: 4.962 GiB, 5.55% gc time, 2.16% compilation time)

# UNSTAGED 
# 18.471672 seconds (86.43 M allocations: 4.259 GiB, 9.08% gc time, 2.24% compilation time)
=======
end
>>>>>>> master
