
# =============================================================
# ================== INTERPRETER ==============================
# =============================================================

struct Sub
  # sourcenode::Union{Nothing, AbstractENode}
  ids::NTuple{N,EClassId} where {N}
  nodes::NTuple{N,Union{Nothing,ENodeLiteral}} where {N}
end

haseclassid(sub::Sub, p::PatVar) = sub.ids[p.idx] >= 0
geteclassid(sub::Sub, p::PatVar) = sub.ids[p.idx]

hasliteral(sub::Sub, p::PatVar) = !isnothing(sub.nodes[p.idx])
getliteral(sub::Sub, p::PatVar) = sub.nodes[p.idx]

## ====================== Instantiation =======================

function instantiate(g::EGraph, pat::PatVar, sub::Sub, rule::AbstractRule; kws...)
  hasliteral(sub, pat) && return getliteral(sub, pat).value
  !haseclassid(sub, pat) && error("unbound pattern variable $pat in rule $rule")
  g[geteclassid(sub, pat)]
end

instantiate(g::EGraph, pat::Any, sub::Sub, rule::AbstractRule; kws...) = pat
instantiate(g::EGraph, pat::AbstractPat, sub::Sub, rule::AbstractRule; kws...) = throw(UnsupportedPatternException(pat))

# FIXME instantiate function object as operation instead of symbol if present!!
# This needs a redesign of this pattern matcher
function instantiate(g::EGraph, pat::PatTerm, sub::Sub, rule::AbstractRule)
  eh = exprhead(pat)
  op = operation(pat)
  ar = arity(pat)
  T = gettermtype(g, op, ar)
  children = map(x -> instantiate(g, x, sub, rule), arguments(pat))
  egraph_reconstruct_expression(T, op, children; metadata = nothing, exprhead = eh)
end

## ====================== EMatching Machine =======================

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
    Sub[],
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
  # sourcenode = m.n[m.program.first_nonground]
  ecs = ntuple(i -> m.σ[instr.yields[i]], length(instr.yields))
  nodes = ntuple(i -> m.n[instr.yields[i]], length(instr.yields))
  push!(m.buf, Sub(ecs, nodes))

  return nothing
end

function (m::Machine)(instr::CheckClassEq, pc)
  l = m.σ[instr.left]
  r = m.σ[instr.right]
  if l == r
    next(m, pc)
  end
  return nothing
end

function (m::Machine)(instr::CheckType, pc)
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
  id = m.σ[instr.reg]
  eclass = m.g[id]

  if instr.predicate(m.g, eclass)
    m.σ[instr.reg] = id
    for n in eclass.nodes
      if n isa ENodeLiteral
        m.n[instr.reg] = n
        break
      end
    end
    next(m, pc)
  end

  return nothing
end


function (m::Machine)(instr::Filter, pc)
  id, _ = m.σ[instr.reg]
  eclass = m.g[id]

  if operation(instr) ∈ funs(eclass)
    next(m, pc + 1)
  end
  return nothing
end

# Thanks to Max Willsey and Yihong Zhang

function lookup_pat(g::EGraph, p::PatTerm)::EClassId
  @assert isground(p)

  eh = exprhead(p)
  op = operation(p)
  args = arguments(p)
  ar = arity(p)

  T = gettermtype(g, op, ar)
  
  ids = ntuple(i -> lookup_pat(g, args[i]), ar)
  !all(i -> i > 0, ids) && return -1

  id = lookup(g, ENodeTerm{T}(eh, op, ids)) 
  if id < 0 && op isa Union{Function,DataType}
    return lookup(g, ENodeTerm{T}(eh, nameof(op), ids))
  end
  id
end

lookup_pat(g::EGraph, p::Any) = lookup(g, ENodeLiteral(p))
lookup_pat(g::EGraph, p::AbstractPat) = throw(UnsupportedPatternException(p))

function (m::Machine)(instr::Lookup, pc)
  ecid = lookup_pat(m.g, instr.p)
  if ecid > 0
    # println("found $(instr.p) in $ecid")
    m.σ[instr.reg] = ecid
    next(m, pc)
  end
  return nothing
end

function (m::Machine)(instr::Bind, pc)
  ecid = m.σ[instr.reg]
  eclass = m.g[ecid]
  pat = instr.enodepat
  reg = instr.reg

  for n in eclass.nodes
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
checkop(x::Union{Function,DataType},op) = isequal(x, op) || isequal(nameof(x), op)
checkop(x,op)= isequal(x, op)

function canbind(n::ENodeTerm, pat::ENodePat)
  exprhead(n) == exprhead(pat) && checkop(operation(pat), operation(n)) && arity(n) == arity(pat)
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
  tid = Threads.threadid()
  m, mlock = MACHINES[tid]
  buf = lock(mlock) do
    reset(m, g, program, id)
    m()
  end
  buf
end
