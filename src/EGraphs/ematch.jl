# TODO make it yield enodes only? ping pavel and marisa
# TODO STAGE IT! FASTER!
# for register memory and for substitutions
# TODO implement https://github.com/egraphs-good/egg/pull/74

using AutoHashEquals

abstract type Instruction end 

const Program = Vector{Instruction}

const Register = Int32

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

function compile_pat(reg, p::PatTerm, ctx, count)
    # a = [gensym() for i in 1:length(p.args)]
    c = count[]
    a = c:(c+length(p.args) - 1)

    # println(p)
    # println(a)
    # filters = [] 
    # for (i, child) in enumerate(p.args) 
    #     if child isa PatTerm
    #         push!(filters, Filter(a[i], child.head, arity(child)))
    #     end
    # end
    # println(filters)

    count[] = c + length(p.args)
    binder = Bind(reg, ENodePat(p.head, a))
    rest = [compile_pat(reg, p2, ctx, count) for (reg, p2) in zip(a, p.args)]

    # return vcat(binder, filters, rest...)
    return vcat(binder, rest...)

end

function compile_pat(reg, p::PatVar, ctx, count)
    if ctx[p.idx] != -1
        return CheckClassEq(reg, ctx[p.idx])
    else
        ctx[p.idx] = reg
        return []
    end
end

function compile_pat(reg, p::PatTypeAssertion, ctx, count)
    if ctx[p.var.idx] != -1
        return CheckClassEq(reg, ctx[p.var.idx])
    else
        ctx[p.var.idx] = reg
        return CheckType(reg, p.type)
    end
end

function compile_pat(reg, p::PatLiteral, ctx, count)
    return Bind(reg, ENodePat(p.val, 0:-1))
end

function compile_pat(reg, p::PatEquiv, ctx, count)
    return [compile_pat(reg, p.left, ctx, count), compile_pat(reg, p.right, ctx, count)]
end

# EXPECTS INDEXES OF PATTERN VARIABLES TO BE ALREADY POPULATED
function compile_pat(p::Pattern)
    pvars = patvars(p)
    nvars = length(pvars)

    count = Ref(2)
    ctx = fill(-1, nvars)

    # println("compiling pattern $p")
    # println(pvars)
    insns = compile_pat(1, p, ctx, count)
    # println("compiled pattern ctx is $ctx")
    return vcat(insns, Yield(ctx)), ctx, count[]
end


# =============================================================
# ================== INTERPRETER ==============================
# =============================================================

mutable struct Machine
    g::EGraph 
    program::Program
    # eclass register memory 
    σ::Vector{EClassId}
    # literals 
    n::Vector{Union{Nothing,ENode}}
    # output buffer
    buf::Vector{Sub}
end

const DEFAULT_MEM_SIZE = 1024
function Machine() 
    m = Machine(
        EGraph(), # egraph
        Program(), # program 
        fill(-1, DEFAULT_MEM_SIZE), # memory
        fill(nothing, DEFAULT_MEM_SIZE), # memory
        Sub[]
    )
    return m 
end

function reset(m::Machine, g, program, memsize, id) 
    m.g = g
    m.program = program

    if memsize > DEFAULT_MEM_SIZE
        error("E-Matching Virtual Machine Memory Overflow")
    end

    fill!(m.σ, -1)
    fill!(m.n, nothing)
    m.σ[1] = id

    empty!(m.buf)

    return m 
end


function (m::Machine)()
    m(m.program[1], 1)
    return m.buf
end

function next(m::Machine, pc)
    m(m.program[pc+1], pc+1)
end

function (m::Machine)(instr::Yield, pc)
    ecs = [m.σ[reg] for reg in instr.yields]
    nodes = [m.n[reg] for reg in instr.yields]
    push!(m.buf, Sub(ecs, nodes))
    return nothing
end

function (m::Machine)(instr::CheckClassEq, pc) 
    if m.σ[instr.left] == m.σ[instr.right]
        next(m, pc)
    end
    return nothing
end

function (m::Machine)(instr::CheckType, pc) 
    id = m.σ[instr.reg]
    eclass = m.g[id]

    for n in eclass 
        if arity(n) == 0 && typeof(n.head) <: instr.type
            m.σ[instr.reg] = id
            m.n[instr.reg] = n
            next(m, pc)
        end
    end

    return nothing
end

function (m::Machine)(instr::Filter, pc)
    id, _ = m.σ[instr.reg]
    eclass = m.g[id]

    if instr.head ∈ funs(eclass)
        next(m, pc+1)
    end
    return nothing
end

function (m::Machine)(instr::Bind, pc) 
    ecid = m.σ[instr.reg]
    eclass = m.g[ecid]

    for n in eclass.nodes
        if n.head == instr.enodepat.head && length(n.args) == length(instr.enodepat.args)
            m.n[instr.reg] = n
            for (j,v) in enumerate(instr.enodepat.args)
                m.σ[v] = n.args[j]
            end
            next(m, pc)
        end
    end
    return nothing
end


# Global Right Hand Side function cache for dynamic rules.
# Now we're talking.
# TODO use a LRUCache?
const EMATCH_PROG_CACHE = IdDict{Pattern, Tuple{Program, Vector{Int64}, Int64}}()
const EMATCH_PROG_CACHE_LOCK = ReentrantLock()

function getprogram(p::Pattern)
    lock(EMATCH_PROG_CACHE_LOCK) do
        if !haskey(EMATCH_PROG_CACHE, p)
            # println("cache miss!")
            program, ctx, memsize = compile_pat(p)
            EMATCH_PROG_CACHE[p] = (program, ctx, memsize)
            return (program, ctx, memsize)
        end
        return EMATCH_PROG_CACHE[p]
    end
end

MACHINES = Machine[] 

function __init__() 
    global MACHINES = map(x -> Machine(), 1:Threads.nthreads())
end

function ematch(g::EGraph, p::Pattern, id::Int64)
    program, ctx, memsize = getprogram(p)
    tid = Threads.threadid() 
    reset(MACHINES[tid], g, program, memsize, id)
    # machine = Machine(g, program, σsize, id)
    buf = MACHINES[tid]()
    
    # println(buf)
    buf
end