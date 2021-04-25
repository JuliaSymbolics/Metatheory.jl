
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

function reset(m::Machine, g, program, id) 
    m.g = g
    m.program = program

    if program.memsize > DEFAULT_MEM_SIZE
        error("E-Matching Virtual Machine Memory Overflow")
    end

    fill!(m.σ, -1)
    fill!(m.n, nothing)
    m.σ[program.first_nonground] = id

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
    l = m.σ[instr.left]
    r = m.σ[instr.right]
    # println("checking eq $l == $r")
    if l == r 
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

# Thanks to Max Willsey and Yihong Zhang

function lookup_pat(g::EGraph, p::PatTerm)
    # println("looking up $p")
    @assert isground(p)

    f = p.head
    ar = arity(p)
    if p.head == :call 
        @assert p.args[1] isa PatLiteral
        f = p.args[1].val
        ar = ar-1
    end

    T = gettermtype(g, f, ar)

    # FIXME metadata
    ids = [lookup_pat(g, pp) for pp in p.args]
    if all(i -> i isa EClassId, ids)
        # println(ids)
        n = ENode{T}(p.head, ids, nothing)
        # println("ENode{$T} $n")
        ec = lookup(g, n)
        return ec
    else 
        return nothing 
    end
end

function lookup_pat(g::EGraph, p::PatLiteral)
    # println("looking up literal $p")
    ec = lookup(g, ENode(p.val))
    return ec
end

function (m::Machine)(instr::Lookup, pc) 
    ecid = lookup_pat(m.g, instr.p)
    if ecid isa EClassId
        # println("found $(instr.p) in $ecid")
        m.σ[instr.reg] = ecid
        next(m, pc)
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
# (pattern, can_optimize_ground) => program
const EMATCH_PROG_CACHE = IdDict{Tuple{Pattern, Bool}, Program}()
const EMATCH_PROG_CACHE_LOCK = ReentrantLock()

function getprogram(p::Pattern, can_optimize)
    lock(EMATCH_PROG_CACHE_LOCK) do
        if !haskey(EMATCH_PROG_CACHE, (p, can_optimize))
            # println("cache miss!")
            program = compile_pat(p, can_optimize)
            EMATCH_PROG_CACHE[(p, can_optimize)] = program
            return program
        end
        return EMATCH_PROG_CACHE[(p, can_optimize)]
    end
end

MACHINES = Machine[] 

function __init__() 
    global MACHINES = map(x -> Machine(), 1:Threads.nthreads())
end

function ematch(g::EGraph, p::Pattern, id::Int64)
    program = getprogram(p, g.can_optimize_ground_terms)
    tid = Threads.threadid() 
    reset(MACHINES[tid], g, program, id)
    # machine = Machine(g, program, σsize, id)
    buf = MACHINES[tid]()
    
    # println(buf)
    buf
end