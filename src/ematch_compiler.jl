# TODO make it yield enodes only? ping pavel and marisa
# TODO STAGE IT! FASTER!
module EMatchCompiler

using AutoHashEquals
using TermInterface
using Metatheory: alwaystrue, binarize, binarize_rec
using Metatheory.Patterns

abstract type Instruction end
export Instruction

const Register = Int32

mutable struct Program
  instructions::Vector{Instruction}
  first_nonground::Int
  memsize::Int
  regs::Vector{Register}
  ground_terms::Dict{Any,Register}
end
export Program


function Program()
  Program(Instruction[], 0, 0, [], Dict{AbstractPat,Register}())
end

hasregister(prog::Program, i) = (prog.regs[i] != -1)
getregister(prog::Program, i) = prog.regs[i]
setregister(prog::Program, i, v) = (prog.regs[i] = v)
increment(prog::Program, i) = (prog.memsize += i)
memsize(prog::Program) = prog.memsize

Base.getindex(p::Program, i) = p.instructions[i]
Base.length(p::Program) = length(p.instructions)

@auto_hash_equals struct ENodePat
  exprhead::Union{Symbol,Nothing}
  operation::Any
  # args::Vector{Register} 
  args::UnitRange{Register}
  checkop::Function # function that checks both symbol or func. object as op
end
export ENodePat

TermInterface.operation(p::ENodePat) = p.operation
TermInterface.exprhead(p::ENodePat) = p.exprhead
TermInterface.arguments(p::ENodePat) = p.args
TermInterface.arity(p::ENodePat) = length(p.args)

@auto_hash_equals struct Bind <: Instruction
  reg::Register
  enodepat::ENodePat
end
export Bind

@auto_hash_equals struct CheckClassEq <: Instruction
  left::Register
  right::Register
end
export CheckClassEq

@auto_hash_equals struct CheckType <: Instruction
  reg::Register
  type::Any
end
export CheckType

@auto_hash_equals struct CheckPredicate <: Instruction
  reg::Register
  predicate::Function
end
export CheckPredicate

@auto_hash_equals struct Yield <: Instruction
  yields::Vector{Register}
end
export Yield

@auto_hash_equals struct Filter <: Instruction
  reg::Register
  operation::Any
  arity::Int
end
TermInterface.operation(x::Filter) = x.operation
export Filter

@auto_hash_equals struct Lookup <: Instruction
  reg::Register
  p::Any # pattern
end
export Lookup

@auto_hash_equals struct Fail <: Instruction
  err::Exception
end
export Fail

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


function compile_ground!(reg, p::AbstractPat, prog)
  push!(prog.instructions, Fail(UnsupportedPatternException(p)))
end

# A literal that is not a pattern
function compile_ground!(reg, p::Any, prog)
  if haskey(prog.ground_terms, p)
    return nothing
  end
  prog.ground_terms[p] = reg
  push!(prog.instructions, Lookup(reg, p))
  increment(prog, 1)
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
  nargs = arity(p)
  # registers unit range
  regrange = c:(c + nargs - 1)

  exhead = exprhead(p)
  op = operation(p)
  checkop = x -> isequal(x, op)

  if op isa Symbol
    checkop = try
      fobj = getproperty(p.mod, op)
      (x) -> (isequal(x, op) || isequal(x, fobj))
    catch e
      e isa UndefVarError ? checkop : rethrow(e)
    end
  end

  increment(prog, nargs)

  push!(prog.instructions, Bind(reg, ENodePat(exhead, op, regrange, checkop)))
  for (reg, p2) in zip(regrange, arguments(p))
    compile_pat!(reg, p2, prog)
  end
end


function compile_pat!(reg, p::PatVar, prog)
  if hasregister(prog, p.idx)
    push!(prog.instructions, CheckClassEq(reg, getregister(prog, p.idx)))
  else # Variable is new
    setregister(prog, p.idx, reg)
    if p.predicate isa Function && p.predicate != alwaystrue
      push!(prog.instructions, CheckPredicate(reg, p.predicate))
    elseif p.predicate isa Type
      push!(prog.instructions, CheckType(reg, p.predicate))
    end
  end
end

function compile_pat!(reg, p::AbstractPat, prog)
  push!(prog.instructions, Fail(UnsupportedPatternException(p)))
end

# Literal values
function compile_pat!(reg, p::Any, prog)
  if haskey(prog.ground_terms, p)
    push!(prog.instructions, CheckClassEq(reg, prog.ground_terms[p]))
    return nothing
  end
  @error "This shouldn't be printed. Report an issue for ematching literals" p
end


#= ====================================================================================== =#

# EXPECTS INDEXES OF PATTERN VARIABLES TO BE ALREADY POPULATED
function compile_pat(p)
  p = binarize_rec(p)
  pvars = patvars(p)
  nvars = length(pvars)

  # The program will try to match against ground terms first
  prog = Program(Instruction[], 1, 1, fill(-1, nvars), Dict{AbstractPat,Register}())
  compile_ground!(1, p, prog)
  prog.first_nonground = prog.memsize
  prog.memsize += 1

  # And then try to match against other patterns
  compile_pat!(prog.first_nonground, p, prog)
  push!(prog.instructions, Yield(prog.regs))
  return prog
end

export compile_pat

end
