# TODO make it work for every pattern type
# TODO make it yield enodes only: ping pavel and marisa
# TODO STAGE IT! FASTER!
# TODO make it linear, use vectors and positions instead of arrays
# for register memory and for substitutions

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

function compile_pat(reg, p::PatTerm, ctx, count)
    # a = [gensym() for i in 1:length(p.args)]
    c = count[]
    a = c:(c+length(p.args) - 1)

    # println(a)
    # @assert length(a) == length(p.args)

    count[] = c + length(p.args)
    binder = Bind(reg, ENodePat(p.head, a))
    return vcat( binder, [compile_pat(reg, p2, ctx, count) for (reg, p2) in zip(a, p.args)]...)
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

# TODO works also for ground terms (?)!
# function compile_pat(reg, p::PatLiteral, ctx)
#     return Check(reg, p.val)
# end

function compile_pat(reg, p::PatLiteral, ctx, count)
    return Bind(reg, ENodePat(p.val, 0:-1))
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
    return vcat(insns, Yield(ctx)), count[]
end


# =============================================================
# ================== INTERPRETER ==============================
# =============================================================

mutable struct Machine
    g::EGraph 
    program::Program
    # register memory 
    σ::Vector{Tuple{Int64, Int64}}
    pc::Int64
    # enode position in currently opened eclass 
    position::Int64
    # stack of instruction_id, enode_position
    bstack::Vector{Tuple{Int64, Int64}}
    # output buffer
    buf::Vector{Sub}
end

const DEFAULT_MEM_SIZE = 1024
function Machine() 
    m = Machine(
        EGraph(), # egraph
        Program(), # program 
        fill((-1,-1), 1024), # memory
        1, # pc
        1, # position
        Tuple{Int64,Int64}[], # bstack
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

    for i ∈ 1:DEFAULT_MEM_SIZE
        m.σ[i] = (-1,-1)
    end
    m.σ[1] = (id, -1)

    m.pc = 1
    m.position = 1
    empty!(m.bstack)
    empty!(m.buf)

    return m 
end

function (m::Machine)()
    while m.pc != -1
        # run the current instruction
        m(m.program[m.pc])
    end
    return m.buf
end

function backtrack(m::Machine)
    if isempty(m.bstack)
        m.pc = -1
    else 
        pc, pos = pop!(m.bstack)
        m.pc = pc 
        m.position = pos
    end
end

function (m::Machine)(instr::Yield) 
    push!(m.buf, [m.σ[reg] for reg in instr.yields])
    backtrack(m)
end

function (m::Machine)(instr::CheckClassEq) 
    if m.σ[instr.left] == m.σ[instr.right]
        m.pc += 1
        return 
    end
    backtrack(m)
end

function (m::Machine)(instr::CheckType) 
    id, literal = m.σ[instr.reg]
    eclass = m.g[id]
    i = m.position

    if i ∈ 1:length(eclass.nodes)
        push!(m.bstack, (m.pc, i+1))
        n = eclass.nodes[i]

        if arity(n) == 0 && typeof(n.head) <: instr.type
            m.σ[instr.reg] = (id, i)
            m.pc += 1
            m.position = 1
            return
        end
    end
    backtrack(m)
end


function (m::Machine)(instr::Bind) 
    ecid, literal = m.σ[instr.reg]
    eclass = m.g[ecid]

    if m.position ∈ 1:length(eclass.nodes)
        push!(m.bstack, (m.pc, m.position+1))
        n = eclass.nodes[m.position]
        if n.head == instr.enodepat.head && length(n.args) == length(instr.enodepat.args)
            for (j,v) in enumerate(instr.enodepat.args)
                m.σ[v] = (n.args[j], -1)
            end
            m.pc += 1
            m.position = 1
            return 
        end
    end
    backtrack(m)
end


# Global Right Hand Side function cache for dynamic rules.
# Now we're talking.
# TODO use a LRUCache?
const EMATCH_PROG_CACHE = IdDict{Pattern, Tuple{Program, Int64}}()
const EMATCH_PROG_CACHE_LOCK = ReentrantLock()

function getprogram(p::Pattern)
    lock(EMATCH_PROG_CACHE_LOCK) do
        if !haskey(EMATCH_PROG_CACHE, p)
            # println("cache miss!")
            program, σsize = compile_pat(p)
            EMATCH_PROG_CACHE[p] = (program, σsize)
        end
        return EMATCH_PROG_CACHE[p]
    end
end

MACHINES = Machine[] 

function __init__() 
    global MACHINES = map(x -> Machine(), 1:Threads.nthreads())
end

function ematch(g::EGraph, p::Pattern, id::Int64)
    program, memsize = getprogram(p)
    tid = Threads.threadid() 
    reset(MACHINES[tid], g, program, memsize, id)
    # machine = Machine(g, program, σsize, id)
    buf = MACHINES[tid]()
    # println(buf)
    buf
end