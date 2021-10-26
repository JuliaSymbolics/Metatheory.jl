
# =============================================================
# ================== INTERPRETER ==============================
# =============================================================

struct Sub
    # sourcenode::Union{Nothing, AbstractENode}
    ids::Vector{EClassId}
    nodes::Vector{Union{Nothing,ENodeLiteral}}
end

haseclassid(sub::Sub, p::PatVar) = sub.ids[p.idx] >= 0
geteclassid(sub::Sub, p::PatVar) = sub.ids[p.idx]

hasliteral(sub::Sub, p::PatVar) = sub.nodes[p.idx] !== nothing
getliteral(sub::Sub, p::PatVar) = sub.nodes[p.idx] 

## ====================== Instantiation =======================

function instantiate(g::EGraph, pat::PatVar, sub::Sub, rule::AbstractRule)
    if haseclassid(sub, pat)
        ec = g[geteclassid(sub, pat)]
        if hasliteral(sub, pat) 
            node = getliteral(sub, pat)
            return node.value
        end 
        return ec
    else
        error("unbound pattern variable $pat in rule $rule")
    end
end

instantiate(g::EGraph, pat::Any, sub::Sub, rule::AbstractRule) = pat
instantiate(g::EGraph, pat::AbstractPat, sub::Sub, rule::AbstractRule) = 
    throw(UnsupportedPatternException(pat))

# FIXME instantiate function object as operation instead of symbol if present!!
function instantiate(g::EGraph, pat::PatTerm, sub::Sub, rule::AbstractRule)
    eh = exprhead(pat)
    op = operation(pat)
    ar = arity(pat)

    T = gettermtype(g, op, ar)
    println(T)
    children = map(x -> instantiate(g, x, sub, rule), arguments(pat))
    similarterm(T, op, children; exprhead=eh)
end



mutable struct Machine
    g::EGraph 
    program::Program
    # eclass register memory 
    σ::Vector{EClassId}
    # literals 
    n::Vector{Union{Nothing,ENodeLiteral}}
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
    m(m.program[pc + 1], pc + 1)
end

function (m::Machine)(instr::Yield, pc)
    # @show instr
    # sourcenode = m.n[m.program.first_nonground]
    ecs = [m.σ[reg] for reg in instr.yields]
    nodes = [m.n[reg] for reg in instr.yields]
    # push!(m.buf, Sub(sourcenode, ecs, nodes))
    push!(m.buf, Sub(ecs, nodes))

    return nothing
end

function (m::Machine)(instr::CheckClassEq, pc) 
    # @show instr
    l = m.σ[instr.left]
    r = m.σ[instr.right]
    # println("checking eq $l == $r")
    if l == r 
        next(m, pc)
    end
    return nothing
end

function (m::Machine)(instr::CheckType, pc) 
    # @show instr
    id = m.σ[instr.reg]
    eclass = m.g[id]

    for n in eclass 
        if checktype(n, instr.type)
            m.σ[instr.reg] = id
            m.n[instr.reg] = n
            next(m, pc)
        end
    end

    return nothing
end

checktype(n, t) = false
checktype(n::ENodeLiteral{<:T}, ::Type{T}) where {T} = true


function (m::Machine)(instr::CheckPredicate, pc) 
    # @show instr
    id = m.σ[instr.reg]
    eclass = m.g[id]

    if instr.predicate(m.g, eclass)
        m.σ[instr.reg] = id
        !isempty(eclass.nodes) && (m.n[instr.reg] = eclass[1])
        next(m, pc)
    end

    return nothing
end


function (m::Machine)(instr::Filter, pc)
    # @show instr
    id, _ = m.σ[instr.reg]
    eclass = m.g[id]

    if operation(instr) ∈ funs(eclass)
        next(m, pc + 1)
    end
    return nothing
end

# Thanks to Max Willsey and Yihong Zhang

function lookup_pat(g::EGraph, p::PatTerm)
    # println("looking up $p")
    @assert isground(p)

    eh = exprhead(p)
    op = operation(p)
    args = arguments(p)
    ar = arity(p)

    T = gettermtype(g, op, ar)

    ids = [lookup_pat(g, pp) for pp in args]
    if all(i -> i isa EClassId, ids)
        # println(ids)
        n = ENodeTerm{T}(eh, op, ids)
        ec = lookup(g, n)
        return ec
    else 
        return nothing 
    end
end

lookup_pat(g::EGraph, p::Any) = lookup(g, ENodeLiteral(p))
lookup_pat(g::EGraph, p::AbstractPat) = throw(UnsupportedPatternException(p))

function (m::Machine)(instr::Lookup, pc) 
    # @show instr
    ecid = lookup_pat(m.g, instr.p)
    if ecid isa EClassId
        # println("found $(instr.p) in $ecid")
        m.σ[instr.reg] = ecid
        next(m, pc)
    end
    return nothing
end

function (m::Machine)(instr::Bind, pc) 
    # @show instr
    ecid = m.σ[instr.reg]
    eclass = m.g[ecid]
    pat = instr.enodepat
    reg = instr.reg

    for n in eclass.nodes
        # @show n
        # @show exprhead(n) exprhead(instr.enodepat)
        # @show operation(n) operation(instr.enodepat)
        # dump(operation(n))
        # dump(operation(instr.enodepat))
        # @show arity(n) arity(instr.enodepat)
        # @show arguments(n) arguments(instr.enodepat)

        # @show exprhead(n) == exprhead(instr.enodepat)
        # @show operation(n) == operation(instr.enodepat)
        # @show arity(n) == arity(instr.enodepat)
        if canbind(n, pat)
            # m.n[reg] = n
            for (j, v) in enumerate(arguments(pat))
                m.σ[v] = arguments(n)[j]
            end
            next(m, pc)
        end
    end
    return nothing
end

function canbind(n::ENodeTerm, pat::ENodePat)
    exprhead(n) == exprhead(pat) &&
        pat.checkop(operation(n)) && 
        arity(n) == arity(pat)
end

canbind(n::ENodeLiteral, pat::ENodePat) = false

# use const to help the compiler see the type.
# each machine has a corresponding lock to ensure thread-safety in case 
# tasks migrate between threads.
const MACHINES = Tuple{Machine,ReentrantLock}[] 

function __init__() 
    empty!(MACHINES)
    for _ in 1:Threads.nthreads()
        push!(MACHINES, (Machine(), ReentrantLock()))
    end
end

function ematch(g::EGraph, program::Program, id::EClassId)
    # @show program
    tid = Threads.threadid() 
    m, mlock = MACHINES[tid]
    buf = lock(mlock) do
        reset(m, g, program, id)
        m()
    end
    # @show buf
    buf
end