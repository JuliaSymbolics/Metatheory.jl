Base.@kwdef mutable struct EMatchCompilerState
  """
  As ground terms are matched at the beginning.
  Store the index of the σ variable (address) that represents the first non-ground term.
  """
  first_nonground::Int = 0

  "Ground terms e-class IDs can be stored in a single σ variable"
  ground_terms_to_addr::Dict{Pat,Int} = Dict{Pat,Int}()

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
      ematch_buffer::$(Metatheory.OptBuffer){UInt64},
    )::Int
      # If the constants in the pattern are not all present in the e-graph, just return
      $(pat_constants_checks...)
      # Initialize σ variables (e-classes memory) and enode iteration indexes
      $(make_memory(state.memsize, state.first_nonground)...)
      # Each node in the pattern can store an index of an enode to iterate the e-classes
      $([:($(Symbol(:enode_idx, i)) = 1) for i in state.enode_idx_addresses]...)
      # Each pattern variable can yield a literal. Store enode literal hashes in these variables
      $([:($(Symbol(:literal_hash, i)) = UInt64(0)) for i in state.patvar_to_addr]...)

      n_matches = 0
      # Backtracking stack
      stack_idx = 0

      # TODO: comment
      isliteral_bitvec = UInt64(0)

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

# TODO document
function check_constant_exprs!(buf, pat::Pat)
  if pat.type === PAT_LITERAL
    push!(buf, :(has_constant(g, $(pat.head_hash)) || return 0))
  elseif pat.type === PAT_EXPR
    if !(pat.head isa Pat)
      push!(buf, :(has_constant(g, $(pat.head_hash)) || has_constant(g, $(pat.name_hash)) || return 0))
    end
    for child in pat.children
      check_constant_exprs!(buf, child)
    end
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

# Ground e-matchers
function ematch_compile_ground!(pat::Pat, state::EMatchCompilerState, addr::Int)
  # Don't compile non-ground terms as ground terms
  pat.type === PAT_VARIABLE || pat.type === PAT_SEGMENT || haskey(state.ground_terms_to_addr, pat) && return nothing

  if pat.isground
    # Remember that it has been searched and its stored in σaddr
    state.ground_terms_to_addr[pat] = addr
    # Add the lookup instruction to the program
    push!(state.program, lookup_expr(addr, pat))
    # Memory needs one more register
    state.memsize += 1
  elseif pat.type === PAT_EXPR
    # Search for ground patterns in the children.
    for child_p in pat.children
      ematch_compile_ground!(child_p, state, state.memsize)
    end
  end
end

# ==============================================================
# Term E-Matchers
# ==============================================================

function ematch_compile!(p::Pat, state::EMatchCompilerState, addr::Int)
  if p.type === PAT_EXPR
    ematch_compile_expr!(p, state, addr)
  elseif p.type === PAT_VARIABLE
    ematch_compile_var!(p, state, addr)
  elseif p.type === PAT_LITERAL
    ematch_compile_literal!(p, state, addr)
  else
    # Pattern is not supported
    push!(
      state.program,
      :(throw(DomainError(p, "Pattern type $(typeof(p)) not supported in e-graph pattern matching")); return 0),
    )
  end
end

function ematch_compile_expr!(p::Pat, state::EMatchCompilerState, addr::Int)
  @assert p.type === PAT_EXPR

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


function ematch_compile_var!(p::Pat, state::EMatchCompilerState, addr::Int)
  @assert p.type === PAT_VARIABLE

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
    # Runtime dispatch needed
    check_var_expr(addr, p.predicate, p.idx)
  end
  push!(state.program, instruction)
end


function ematch_compile_literal!(p::Pat, state::EMatchCompilerState, addr::Int)
  @assert p.type === PAT_LITERAL
  push!(state.program, check_eq_expr(addr, state.ground_terms_to_addr[p]))
end


# ==============================================================
# Actual Instructions
# ==============================================================

function bind_expr(addr::Int, p::Pat, memrange)
  @assert p.type === PAT_EXPR
  quote
    eclass = g[$(Symbol(:σ, addr))]
    eclass_length = length(eclass.nodes)
    if $(Symbol(:enode_idx, addr)) <= eclass_length
      push!(stack, pc)

      n = eclass.nodes[$(Symbol(:enode_idx, addr))]

      v_flags(n) === $(v_flags(p.n)) || @goto $(Symbol(:skip_node, addr))
      v_signature(n) === $(v_signature(p.n)) || @goto $(Symbol(:skip_node, addr))
      v_head(n) === $(v_head(p.n)) || (v_head(n) === $(p.name_hash) || @goto $(Symbol(:skip_node, addr)))

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

function check_var_expr(::Int, ::typeof(alwaystrue), idx::Int64)
  quote
    # TODO: see if this is needed
    # eclass = g[$(Symbol(:σ, addr))]
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

function check_var_expr(addr::Int, predicate::Function, idx::Int64)
  quote
    eclass = g[$(Symbol(:σ, addr))]
    if ($predicate)(g, eclass)
      for (j, n) in enumerate(eclass.nodes)
        # TODO does this make sense? This should be unset.
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


"""
Generates a pattern matching expression that given a σ address `addr::Int`
and a predicate checking a type `T`, iterates an e-class stored in the e-graph `g` at ID given by
pattern-matcher local variable `σaddr`, and matches if the
e-class contains at least a literal that is of type
"""
function check_var_expr(addr::Int, predicate::Base.Fix2{typeof(isa),<:Type}, idx::Int64)
  quote
    eclass = g[$(Symbol(:σ, addr))]
    eclass_length = length(eclass.nodes)
    if $(Symbol(:enode_idx, addr)) <= eclass_length
      push!(stack, pc)
      n = eclass.nodes[$(Symbol(:enode_idx, addr))]

      if !v_isexpr(n)
        h = v_head(n)
        hn = Metatheory.EGraphs.get_constant(g, h)
        if $(predicate)(hn)
          $(Symbol(:enode_idx, addr)) += 1
          $(Symbol(:literal_hash, addr)) = h
          isliteral_bitvec = v_bitvec_set(isliteral_bitvec, $idx)
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
function check_eq_expr(addr_a::Int, addr_b::Int)
  quote
    if $(Symbol(:σ, addr_a)) == $(Symbol(:σ, addr_b))
      pc += 0x0001
      @goto compute
    else
      @goto backtrack
    end
  end
end

function lookup_expr(addr::Int, p::Pat)
  @assert p.type === PAT_EXPR || p.type === PAT_LITERAL
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

function yield_expr(patvar_to_addr, direction::Int)
  push_exprs = [
    :(push!(
      ematch_buffer,
      v_bitvec_check(isliteral_bitvec, $i) ? $(Symbol(:literal_hash, addr)) : $(Symbol(:σ, addr)),
    )) for (i, addr) in enumerate(patvar_to_addr)
  ]
  quote
    g.needslock && lock(g.lock)
    push!(ematch_buffer, root_id)
    push!(ematch_buffer, reinterpret(UInt64, rule_idx * $direction))
    push!(ematch_buffer, isliteral_bitvec)

    $(push_exprs...)
    n_matches += 1
    g.needslock && unlock(g.lock)
    @goto backtrack
  end
end

