Base.@kwdef mutable struct EMatchCompilerState
  """
  As ground terms are matched at the beginning. 
  Store the index of the σ variable (address) that represents the first non-ground term.
  """
  first_nonground::Int = 0

  "Ground terms e-class IDs can be stored in a single σ variable"
  ground_terms_to_addr::Dict{AbstractPat,Int} = Dict{AbstractPat,Int}()

  """
  Given a pattern variable with Debrujin index i
  This vector stores the σ variable index (address) for that variable at position i 
  """
  patvar_to_addr::Vector{Int} = Int[]

  """
  Addresses of σ variables that should iterate e-nodes in an e-class, 
  used to generate `enode_idx` variables
  """
  enode_idx_addresses::Vector{Int} = Int[]

  "List of actual e-matching instructions"
  program::Vector{Expr} = Expr[]

  "How many σ variables are needed to e-match"
  memsize = 1
end

function ematch_compile(p, pvars, direction)
  # Create the compiler state with the right number of pattern variables
  state = EMatchCompilerState(; patvar_to_addr = fill(-1, length(pvars)))

  ematch_compile_ground!(p, state, 1)

  state.first_nonground = state.memsize
  state.memsize += 1

  ematch_compile!(p, state, state.first_nonground)

  push!(state.program, yield_expr(state.patvar_to_addr, direction))

  pat_constants_checks = check_constant_exprs!(Expr[], p)

  quote
    function ($(gensym("ematcher")))(
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
      $([:($(Symbol(:enode_idx, i)) = 1) for i in state.enode_idx_addresses]...)

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
      $([:(
        if pc === $(UInt16(i))
          $code
        end
      ) for (i, code) in enumerate(state.program)]...)

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
make_memory(n, first_nonground) = [:($(Symbol(:σ, i)) = $(i == first_nonground ? :root_id : Id(0))) for i in 1:n]

# ==============================================================
# Ground Term E-Matchers
# TODO explain what is a ground term
# ==============================================================

"Don't compile non-ground terms as ground terms"
ematch_compile_ground!(::AbstractPat, ::EMatchCompilerState, ::Int) = nothing

# Ground e-matchers
function ematch_compile_ground!(p::Union{PatExpr,PatLiteral}, state::EMatchCompilerState, addr::Int)
  haskey(state.ground_terms_to_addr, p) && return nothing

  if isground(p)
    # Remember that it has been searched and its stored in σaddr
    state.ground_terms_to_addr[p] = addr
    # Add the lookup instruction to the program
    push!(state.program, lookup_expr(addr, p))
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

function ematch_compile!(p::PatExpr, state::EMatchCompilerState, addr::Int)
  if haskey(state.ground_terms_to_addr, p)
    push!(state.program, check_eq_expr(addr, state.ground_terms_to_addr[p]))
    return
  end

  c = state.memsize
  nargs = arity(p)
  memrange = c:(c + nargs - 1)
  state.memsize += nargs

  push!(state.enode_idx_addresses, addr)
  push!(state.program, bind_expr(addr, p, memrange))
  for (i, child_p) in enumerate(arguments(p))
    ematch_compile!(child_p, state, memrange[i])
  end
end


function ematch_compile!(p::PatVar, state::EMatchCompilerState, addr::Int)
  instruction = if state.patvar_to_addr[p.idx] != -1
    # Pattern variable with the same Debrujin index has appeared in the  
    # pattern before this. Just check if the current e-class id matches the one 
    # That was already encountered.
    check_eq_expr(addr, state.patvar_to_addr[p.idx])
  else
    # Variable has not been seen before. Store its memory address
    state.patvar_to_addr[p.idx] = addr
    # insert instruction for checking predicates or type.
    push!(state.enode_idx_addresses, addr)
    check_var_expr(addr, p.predicate)
  end
  push!(state.program, instruction)
end

# Pattern not supported.
function ematch_compile!(p::AbstractPat, state::EMatchCompilerState, ::Int)
  push!(
    state.program,
    :(throw(DomainError(p, "Pattern type $(typeof(p)) not supported in e-graph pattern matching")); return 0),
  )
end



function ematch_compile!(p::PatLiteral, state::EMatchCompilerState, addr::Int)
  push!(state.program, check_eq_expr(addr, state.ground_terms_to_addr[p]))
end


# ==============================================================
# Actual Instructions
# ==============================================================

function bind_expr(addr, p::PatExpr, memrange)
  quote
    eclass = g.classes[$(Symbol(:σ, addr))]
    eclass_length = length(eclass.nodes)
    if $(Symbol(:enode_idx, addr)) <= eclass_length
      push!(stack, pc)

      n = eclass.nodes[$(Symbol(:enode_idx, addr))]

      v_flags(n) === $(v_flags(p.n)) || @goto $(Symbol(:skip_node, addr))
      v_signature(n) === $(v_signature(p.n)) || @goto $(Symbol(:skip_node, addr))
      v_head(n) === $(v_head(p.n)) || (v_head(n) === $(p.quoted_head_hash) || @goto $(Symbol(:skip_node, addr)))

      # Node has matched.
      $([:($(Symbol(:σ, j)) = n[$i + $VECEXPR_META_LENGTH]) for (i, j) in enumerate(memrange)]...)
      pc += 0x0001
      $(Symbol(:enode_idx, addr)) += 1
      @goto compute

      @label $(Symbol(:skip_node, addr))
      # This node did not match. Try next node and backtrack.
      $(Symbol(:enode_idx, addr)) += 1
      @goto backtrack
    end


    # # Restart from first option
    $(Symbol(:enode_idx, addr)) = 1
    @goto backtrack
  end
end

function check_var_expr(addr, predicate::typeof(alwaystrue))
  quote
    # eclass = g.classes[$(Symbol(:σ, addr))]
    # for (j, n) in enumerate(eclass.nodes)
    #   if !v_isexpr(n)
    #     $(Symbol(:enode_idx, addr)) = j + 1
    #     break
    #   end
    # end
    pc += 0x0001
    @goto compute
  end
end

function check_var_expr(addr, predicate::Function)
  quote
    eclass = g.classes[$(Symbol(:σ, addr))]
    if ($predicate)(g, eclass)
      for (j, n) in enumerate(eclass.nodes)
        if !v_isexpr(n)
          $(Symbol(:enode_idx, addr)) = j + 1
          break
        end
      end
      pc += 0x0001
      @goto compute
    end
    @goto backtrack
  end
end


function check_var_expr(addr, T::Type)
  quote
    eclass = g.classes[$(Symbol(:σ, addr))]
    eclass_length = length(eclass.nodes)
    if $(Symbol(:enode_idx, addr)) <= eclass_length
      push!(stack, pc)
      n = eclass.nodes[$(Symbol(:enode_idx, addr))]

      if !v_isexpr(n)
        hn = Metatheory.EGraphs.get_constant(g, v_head(n))
        if hn isa $T
          $(Symbol(:enode_idx, addr)) += 1
          pc += 0x0001
          @goto compute
        end
      end

      # This node did not match. Try next node and backtrack.
      $(Symbol(:enode_idx, addr)) += 1
      @goto backtrack
    end

    # Restart from first option
    $(Symbol(:enode_idx, addr)) = 1
    @goto backtrack
  end
end


"""
Constructs an e-matcher instruction `Expr` that checks if 2 e-class IDs 
contained in memory addresses `addr_a` and `addr_b` are equal, 
backtracks otherwise.
"""
function check_eq_expr(addr_a, addr_b)
  quote
    if $(Symbol(:σ, addr_a)) == $(Symbol(:σ, addr_b))
      pc += 0x0001
      @goto compute
    else
      @goto backtrack
    end
  end
end

function lookup_expr(addr, p::AbstractPat)
  quote
    ecid = lookup_pat(g, $p)
    if ecid > 0
      $(Symbol(:σ, addr)) = ecid
      pc += 0x0001
      @goto compute
    end
    @goto backtrack
  end
end

function yield_expr(patvar_to_addr, direction)
  push_exprs = [
    quote
      id = $(Symbol(:σ, addr))
      eclass = g.classes[id]
      node_idx = $(Symbol(:enode_idx, addr)) - 1
      if node_idx <= 0
        push!(ematch_buffer, v_pair(id, reinterpret(UInt64, 0)))
      else
        n = eclass.nodes[node_idx]
        push!(ematch_buffer, v_pair(id, v_head(n)))
      end
    end for
    addr in patvar_to_addr
  ]
  quote
    g.needslock && lock(g.lock)
    push!(ematch_buffer, v_pair(root_id, reinterpret(UInt64, rule_idx * $direction)))
    $(push_exprs...)
    # Add delimiter to buffer. 
    push!(ematch_buffer, 0xffffffffffffffffffffffffffffffff)
    n_matches += 1
    g.needslock && unlock(g.lock)
    @goto backtrack
  end
end

