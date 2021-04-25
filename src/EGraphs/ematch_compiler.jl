# TODO make it yield enodes only? ping pavel and marisa
# TODO STAGE IT! FASTER!

using AutoHashEquals

abstract type Instruction end 

const Register = Int32

mutable struct Program
    instructions::Vector{Instruction}
    first_nonground::Int
    memsize::Int
    regs::Vector{Register}
    ground_terms::Dict{Pattern, Register}
end

function Program()
    Program(Instruction[], 0, 0, [], Dict{Pattern, Register}())
end

hasregister(prog::Program, i) = (prog.regs[i] != -1)
getregister(prog::Program, i) = prog.regs[i] 
setregister(prog::Program, i, v) = (prog.regs[i] = v) 
increment(prog::Program, i) = (prog.memsize += i)
memsize(prog::Program) = prog.memsize

Base.getindex(p::Program, i) = p.instructions[i]
Base.length(p::Program) = length(p.instructions) 

@auto_hash_equals struct ENodePat
    head::Any
    # args::Vector{Register} 
    args::UnitRange{Register}
end

@auto_hash_equals struct Bind <: Instruction
    reg::Register
    enodepat::ENodePat
end

@auto_hash_equals struct CheckClassEq <: Instruction
    left::Register
    right::Register
end

@auto_hash_equals struct CheckType <: Instruction
    reg::Register
    type::Any
end

@auto_hash_equals struct Yield <: Instruction
    yields::Vector{Register}
end

@auto_hash_equals struct Filter <: Instruction
    reg::Register
    head::Any
    arity::Int
end

@auto_hash_equals struct Lookup <: Instruction
    reg::Register
    p::Pattern
end

# =============================================
# ========= GROUND patterns ================
# =============================================


function compile_ground!(reg, p::PatTerm, prog)
    if haskey(prog.ground_terms, p)
        # push!(prog.instructions, CheckClassEq(reg, prog.ground_terms[p]))
        return nothing
    end

    if isground(p)
        prog.ground_terms[p] = reg
        push!(prog.instructions, Lookup(reg, p))
        increment(prog, 1)
    else 
        for p2 in p.args
            compile_ground!(prog.memsize, p2, prog)
        end
    end
end


function compile_ground!(reg, p::PatVar, prog)
    nothing
end

function compile_ground!(reg, p::PatTypeAssertion, prog)
    nothing
end

function compile_ground!(reg, p::PatLiteral, prog)
    if haskey(prog.ground_terms, p)
        return nothing
    end
    prog.ground_terms[p] = reg
    push!(prog.instructions, Lookup(reg, p))
    increment(prog, 1)
end

function compile_ground!(reg, p::PatEquiv, prog)
    compile_ground!(reg, p.left, prog)
    compile_ground!(reg, p.right, prog)
end

# =============================================
# ========= NONGROUND patterns ================
# =============================================

function compile_pat!(reg, p::PatTerm, prog)
    if haskey(prog.ground_terms, p)
        push!(prog.instructions, CheckClassEq(reg, prog.ground_terms[p]))
        return nothing
    end
    # a = [gensym() for i in 1:length(p.args)]
    c = memsize(prog)
    nargs = length(p.args)
    a = c:(c + nargs - 1)

    # println(p)
    # println(a)
    # filters = [] 
    # for (i, child) in enumerate(p.args) 
    #     if child isa PatTerm
    #         push!(filters, Filter(a[i], child.head, arity(child)))
    #     end
    # end
    # println(filters)

    increment(prog, nargs)
    push!(prog.instructions, Bind(reg, ENodePat(p.head, a)))
    for (reg, p2) in zip(a, p.args)
        compile_pat!(reg, p2, prog) 
    end
end

function compile_pat!(reg, p::PatVar, prog)
    if hasregister(prog, p.idx)
        push!(prog.instructions, CheckClassEq(reg, getregister(prog, p.idx)))
    else
        setregister(prog, p.idx, reg)
    end
end

function compile_pat!(reg, p::PatTypeAssertion, prog)
    if hasregister(prog, p.var.idx)
        push!(prog.instructions, CheckClassEq(reg, getregister(prog, p.var.idx)))
    else
        setregister(prog, p.var.idx, reg)
        push!(prog.instructions, CheckType(reg, p.type))
    end
end

function compile_pat!(reg, p::PatLiteral, prog)
    if haskey(prog.ground_terms, p)
        push!(prog.instructions, CheckClassEq(reg, prog.ground_terms[p]))
        return nothing
    end
    push!(prog.instructions, Bind(reg, ENodePat(p.val, 0:-1)))
end

function compile_pat!(reg, p::PatEquiv, prog)
    compile_pat!(reg, p.left, prog)
    compile_pat!(reg, p.right, prog)
end

# EXPECTS INDEXES OF PATTERN VARIABLES TO BE ALREADY POPULATED
function compile_pat(p::Pattern, can_optimize_ground)
    pvars = patvars(p)
    nvars = length(pvars)


    if can_optimize_ground
        # FIXME CUSTOM TERM TYPES IN LITERAL OPTIMIZATION
        # this if would not be needed!!!
        prog = Program(Instruction[], 1, 1, fill(-1, nvars), Dict{Pattern, Register}())
        # println("compiling pattern $p")
        compile_ground!(1, p, prog)
        # println("compiled ground pattern \n $prog")
        prog.first_nonground = prog.memsize
        prog.memsize+=1
    else 
        prog = Program(Instruction[], 1, 2, fill(-1, nvars), Dict{Pattern, Register}())
    end
    compile_pat!(prog.first_nonground, p, prog)
    push!(prog.instructions, Yield(prog.regs))
    # println("compiled pattern $p to \n $prog")
    return prog
end

