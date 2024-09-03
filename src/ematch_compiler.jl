"""
We compile a pattern to a backtracking register machine, just like in
[egg](https://egraphs-good.github.io/), but implemented as a generated Julia
function rather than a virtual machine.

The "instructions" for this register machine are branches in a large if-else
statement that looks like:

```julia
@label compute

if pc === 1
  # do instruction 1
else if pc === 2
  # do instruction 2
else
...
end

@label backtrack
pc = pop!(stack)

@goto compute
```

The "registers" for this register machine are simply local variables inside this
function.

If an instruction "succeeds", it will increment pc, and then `@goto compute`; this
is implemented by [`continue_`](@ref). This has the effect of going to the next instruction in the sequence. If an instruction "fails", it will `@goto backtrack`,
which will go back to the most recent save point (usually an iteration over, say, e-nodes in an e-class). This is implemented by [`backtrack`](@ref).

The one thing that is important to know at the start is that we refer to registers
by "addresses" (which are just integers). To each address `addr`, there are
associated one or two registers: there is always a register `eclass_var(addr)`,
and for some addresses, there is also a register `enode_var(addr)`. The register
`eclass_var(addr)` stores an e-id in the e-graph that we are matching on,
and the register `enode_var(addr)` stores the index of an enode in the eclass
referred to by `eclass_var(addr)`. This is used to, for instance, iterate over
all of the enodes in an e-class.
"""

# ==============================================================
# Codegen support
#
# We generate an ematcher by first producing a list of
# instructions, and then generating a julia function from that
# list of instructions.
#
# This section contains the instructions and their corresponding
# `to_expr` functions
# ==============================================================

"""
These represent "registers" in the register machine to which a pattern match
compiles.

They are stored as local variables, the names of which can be obtained with
asvar.
"""
const Address = Int

eclass_var(addr::Address) = Symbol(:σ, addr)
enode_var(addr::Address) = Symbol(:enode_idx, addr)

abstract type Instruction end

function set_backtrack_checkpoint()
  :(push!(stack, pc))
end

function continue_()
  quote
    pc += 0x0001
    @goto compute
  end
end

function backtrack()
  :(@goto backtrack)
end

"""
Iterates through all of the enodes of the e-class in `eclass_var(addr)`,
and for each enode that has the same (flags, signature, head_hash || quoted_head_hash)
binds the addresses in memrange to the arguments of that enode.

In later instructions, the index of the enode being iterated over" is available
at `enode_var(addr)`. The eids of the arguments are available at
`[eclass_var(addr) for addr in memrange]`.
"""
struct BindExpr <: Instruction
  addr::Address
  flags::Id
  signature::Id
  head_hash::Id
  quoted_head_hash::Id
  memrange::UnitRange{Int}
end

function BindExpr(addr::Address, p::PatExpr, memrange::UnitRange{Int})
  BindExpr(
    addr,
    v_flags(p.n),
    v_signature(p.n),
    p.head_hash,
    p.quoted_head_hash,
    memrange
  )
end

function to_expr(inst::BindExpr)
  addr = inst.addr
  i = enode_var(addr)
  check_flags = :(v_flags(n) === $(inst.flags))
  check_sig = :(v_flags(n) === $(inst.flags))
  check_head = :(v_head(n) === $(inst.head_hash) || v_head(n) === $(inst.quoted_head_hash))
  quote
    eclass = g[$(eclass_var(addr))]
    eclass_length = length(eclass.nodes)

    if $i <= eclass_length
      $(set_backtrack_checkpoint())

      n = eclass.nodes[$i]

      $i += 1
      if $check_flags && $check_sig && $check_head
        $((map(enumerate(inst.memrange)) do (idx, addr)
          :($(eclass_var(addr)) = v_children(n)[$idx])
        end)...)

        $(continue_())
      else
        $(backtrack())
      end
    else
      $i = 1
      $(backtrack())
    end
  end
end

"""
Checks that the e-class for the e-id in `eclass_var(addr)` satisfies `predicate`.

If so, also set `enode_var(addr)` to be one after the first enode
that is not an expression? This doesn't really make sense to me.
"""
struct CheckVar <: Instruction
  addr::Address
  predicate::Union{Function, Type}
end

function to_expr(inst::CheckVar)
  addr = inst.addr
  if inst.predicate isa Function
    quote
      eclass = g[$(eclass_var(addr))]
      if ($inst.predicate)(g, eclass)
        for (j, n) in enumerate(eclass.nodes)
          if !v_isexpr(n)
            $(enode_var(addr)) = j + 1
            break
          end
        end
        $(continue_())
      else
        $(backtrack())
      end
    end
  elseif inst.predicate isa Type
    T = inst.predicate
    i = enode_var(addr)
    quote
      eclass = g[$(eclass_var(addr))]
      eclass_length = length(eclass.nodes)
      if $i <= eclass_length
        $(set_backtrack_checkpoint())

        n = eclass.nodes[$i]

        if !v_isexpr(n)
          hn = Metatheory.EGraphs.get_constant(g, v_head(n))
          if hn isa $T
            $i += 1
            $(continue_())
          end
        end

        # This node did not match. Try next node and backtrack.
        $i += 1
        $(backtrack())
      end

      # Restart from first option
      $(Symbol(:enode_idx, addr)) = 1
      @goto backtrack
    end
  end
end

"""
Checks that the two e-ids in `eclass_var(addr_a)` and `eclass_var(addr_b)` are
equal, continuing if so and backtracking otherwise.
"""
struct CheckEq <: Instruction
  addr_a::Address
  addr_b::Address
end

function to_expr(inst::CheckEq)
  quote
    if $(eclass_var(inst.addr_a)) == $(eclass_var(inst.addr_b))
      $(continue_())
    else
      $(backtrack())
    end
  end
end

"""
Precondition: `p` must be a *grounded* pattern, which means that `p` has no
variables in it.

Checks if the e-graph contains an instance of `p`, and if so, loads the e-id for
`p` into `eclass_var(addr)`.
"""
struct Lookup <: Instruction
  addr::Int
  p::AbstractPat
  function Lookup(addr::Int, p::AbstractPat)
    @assert isground(p)
    new(addr, p)
  end
end

function to_expr(inst::Lookup)
  quote
    ecid = lookup_pat(g, $(inst.p))
    if ecid > 0
      $(eclass_var(inst.addr)) = ecid
      $(continue_())
    else
      $(backtrack())
    end
  end
end

"""
This instruction is called "at the end" of the match process to save a match.

A "finished match" is an assignment of e-id to each variable in the pattern.
The `patvar_to_addr` vector gives the addresses where all of the e-ids can be
found at the end of a match process, and the corresponding e-nodes that were
selected for those e-ids.
"""
struct Yield <: Instruction
  patvar_to_addr::Vector{Address}
  direction::Int
end

function to_expr(inst::Yield)
  push_exprs = [
               :(push!(
                 ematch_buffer,
                 v_pair(
                   $(eclass_var(addr)),
                   reinterpret(UInt64, $(enode_var(addr)) - 1)
                 )
               )) for addr in inst.patvar_to_addr
  ]
  quote
    g.needslock && lock(g.lock)
    push!(ematch_buffer, v_pair(root_id, reinterpret(UInt64, rule_idx * $(inst.direction))))
    $(push_exprs...)
    push!(ematch_buffer, 0xffffffffffffffffffffffffffffffff)
    n_matches += 1
    g.needslock && unlock(g.lock)
    $(backtrack())
  end
end

Base.@kwdef mutable struct EMatchCompilerState
  """
  Ground terms are matched at the beginning.

  This is the index of the σ variable (address) that represents the first
  non-ground term.

  In other words, this is the address of the root pattern that we are
  matching.
  """
  first_nonground::Int = 0

                         """
                         This provides a lookup for the address corresponding to each ground term.
                         """
  ground_terms_to_addr::Dict{AbstractPat, Int} = Dict{AbstractPat,Int}()

  """
  Given a pattern variable with Debrujin index i
  This vector stores the σ variable index (address) for that variable at position i

  This is a vector rather than a Dict... because we Debruijn-index pattern
  variables.
  """
  patvar_to_addr::Vector{Address} = Address[]

  """
  For some addresses, we care not just about the e-class in the address but also
  the e-node in that e-class. This stores the addresses for which that is the
  case.
  """
  enode_var_addresses::Vector{Address} = Address[]

  """
  The program, encoded as a list of instructions
  """
  program::Vector{Instruction} = Instruction[]

  """
  The total number of addresses we need.
  """
  memsize = 1
end

function ematch_compile(p::AbstractPat, pvars, direction::Int)
  state = EMatchCompilerState(; patvar_to_addr = fill(-1, length(pvars)))

  ematch_compile_ground!(p, state, 1)

  state.first_nonground = state.memsize
  state.memsize += 1

  ematch_compile!(p, state, state.first_nonground)

  push!(state.program, Yield(state.patvar_to_addr, direction))

  pat_constants_checks = check_constant_exprs!(Expr[], p)

  quote
    function $(gensym("ematcher"))(
      g::$(Metatheory.EGraphs.EGraph),
      rule_idx::Int,
      root_id::$(Metatheory.Id),
      stack::$(Metatheory.OptBuffer){UInt16},
      ematch_buffer::$(Metatheory.OptBuffer){UInt128},
    )::Int
      # If the constants in the pattern are not all present in the e-graph, just return
      $(pat_constants_checks...)

      # Initialize σ variables (e-classes memory) and enode iteration indexes
      $(make_memory(state.memsize, state.first_nonground)...)
      $((map(state.enode_var_addresses) do addr
        :($(enode_var(addr)) = 1)
      end)...)

      n_matches = 0
      # Backtracking stack
      stack_idx = 0

      # Instruction 0 is used to return when  the backtracking stack is empty.
      # We start from 1.
      push!(stack, 0x0000)
      pc = 0x0001

      # We goto this label when:
      # 1) After backtracking, the pc is popped from the stack.
      # 2) When an instruction succeeds, the pc is incremented.
      @label compute
      # Instruction 0 is used to return when  the backtracking stack is empty.
      pc === 0x0000 && return n_matches

      # For each instruction in the program, create an if statement,
      # Checking if the current value
      $((map(enumerate(state.program)) do (i, inst)
        quote
          if pc === $(UInt16(i))
            $(to_expr(inst))
          end
        end
      end)...)

      error("unreachable code!")

      @label backtrack
      pc = pop!(stack)

      @goto compute

      return -1
    end
  end
end

check_constant_exprs!(buf, p::PatLiteral) = push!(buf, :(has_constant(g, $(last(p.n))) || return 0))
check_constant_exprs!(buf, ::AbstractPat) = buf
function check_constant_exprs!(buf, p::PatExpr)
  if !(p.head isa AbstractPat)
    push!(buf, :(has_constant(g, $(p.head_hash)) || has_constant(g, $(p.quoted_head_hash)) || return 0))
  end
  for child in children(p)
    check_constant_exprs!(buf, child)
  end
  buf
end

"""
Create a vector of assignment expressions in the form of
`σi = 0x0000000000000000` where `i`` is a number from 1 to n.
If `i == first_nonground`, create an expression `σi = root_id`,
where root_id is a parameter of the ematching function, defined
in scope.
"""
make_memory(n, first_nonground) = map(1:n) do i
  :($(eclass_var(i)) = $(i == first_nonground ? :root_id : Id(0)))
end

# ==============================================================
# Ground Term E-Matchers
#
# A ground term is a term without any pattern variables.
# ==============================================================

"Don't compile non-ground terms as ground terms"
ematch_compile_ground!(::AbstractPat, ::EMatchCompilerState, ::Int) = nothing

# Ground e-matchers
# It seems like it's always the case that addr = state.memsize,
# and in fact if this is not the case, there will be bugs?

# I think a better interface would be something like
#
# fresh_addr!(state::EMatchCompilerState)::Int
#
# Also, it seems like ematch_compile_ground! has a different
# contract than ematch_compile!. The contract is that it makes sure that we
# lookup `p` and store its address in `addr`, not that we make sure that `addr`
# contains `p`.
function ematch_compile_ground!(p::Union{PatExpr,PatLiteral}, state::EMatchCompilerState, addr::Int)
  haskey(state.ground_terms_to_addr, p) && return nothing

  if isground(p)
    # Remember that it has been searched and its stored in σaddr
    state.ground_terms_to_addr[p] = addr
    # Add the lookup instruction to the program
    push!(state.program, Lookup(addr, p))
    # Memory needs one more register
    state.memsize += 1
  else
    # Search for ground patterns in the children.
    for child_p in children(p)
      ematch_compile_ground!(child_p, state, state.memsize)
    end
  end
end

# ==============================================================
# Term E-Matchers
# ==============================================================

"""
ematch_compile!(p::AbstractPat, state::EMatchCompilerState, addr::Int)

Emit instructions into `state` that e-match `p` with the e-class that is stored
in `eclass_var(addr)`.
"""
function ematch_compile! end

"""
ematch_compile!(p::PatExpr, state::EMatchCompilerState, addr::Int)

Loop over all the e-nodes in `eclass_var(addr)`, and for each one whose head matches
`p`, place its arguments in new addresses, and keep going.

Special case: if `p` is ground, then we can short-circuit by just checking if
`addr` is equal to the previously-looked up e-class for the ground pattern.
"""
function ematch_compile!(p::PatExpr, state::EMatchCompilerState, addr::Int)
  if haskey(state.ground_terms_to_addr, p)
    push!(state.program, CheckEq(addr, state.ground_terms_to_addr[p]))
    return
  end

  c = state.memsize
  nargs = arity(p)
  memrange = c:(c + nargs - 1)
  state.memsize += nargs

  push!(state.enode_var_addresses, addr)
  push!(state.program, BindExpr(addr, p, memrange))
  for (i, child_p) in enumerate(arguments(p))
    ematch_compile!(child_p, state, memrange[i])
  end
end

"""
ematch_compile!(p::PatVar, state::EMatchCompilerState, addr::Int)

If we have previously bound this var, check if the eclass id in `eclass_var(addr)`
is equal to the previously-bound eclass id.

Otherwise, bind this var to the eclass id in `eclass_var(addr)`, as long as that
eclass id satisfies the predicate attached to `p`.
"""
function ematch_compile!(p::PatVar, state::EMatchCompilerState, addr::Int)
  instruction = if state.patvar_to_addr[p.idx] != -1
    # Pattern variable with the same Debrujin index has appeared in the
    # pattern before this. Just check if the current e-class id matches the one
    # That was already encountered.
    CheckEq(addr, state.patvar_to_addr[p.idx])
  else
    # Variable has not been seen before. Store its memory address
    state.patvar_to_addr[p.idx] = addr
    # insert instruction for checking predicates or type.
    push!(state.enode_var_addresses, addr)
    CheckVar(addr, p.predicate)
  end
  push!(state.program, instruction)
end

# Pattern not supported.
# Why not throw this error right now?
function ematch_compile!(p::AbstractPat, state::EMatchCompilerState, ::Int)
  push!(
    state.program,
    :(throw(DomainError(p, "Pattern type $(typeof(p)) not supported in e-graph pattern matching")); return 0),
  )
end

"""
ematch_compile!(p::PatLiteral, state::EMatchCompilerState, addr::Int)

This is just like the `isground` case of `ematch_compile(p::PatExpr,...)`; we
have already bound all of the constant terms in the pattern to e-classes, so
we just have to run an equality check here.
"""
function ematch_compile!(p::PatLiteral, state::EMatchCompilerState, addr::Int)
  push!(state.program, CheckEq(addr, state.ground_terms_to_addr[p]))
end
