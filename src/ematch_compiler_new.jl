# Full e-matcher
function ematch_compile(p, pvars, direction)
  npvars = length(pvars)

  patvar_to_addr = fill(-1, npvars)
  ground_terms_to_addr = Dict{AbstractPat,Int}()

  program = Expr[]
  memsize = Ref(1)

  ematch_compile_ground!(1, ground_terms_to_addr, program, memsize, p)
  first_nonground = memsize[]
  memsize[] += 1

  ematch_compile!(first_nonground, ground_terms_to_addr, patvar_to_addr, program, memsize, p)

  push!(program, yield_expr(patvar_to_addr, direction))

  pat_constants_checks = check_constant_exprs!(Expr[], p)

  quote
    function ($(gensym("ematcher")))(g::EGraph, rule_idx::Int, root_id::Id, stack::Vector{UInt16})::Int
      # If the constants in the pattern are not all present in the e-graph, just return 
      $(pat_constants_checks...)
      # Copy and empty the memory 
      $(make_memory(memsize[], first_nonground)...)
      $([:($(Symbol(:enode_idx, i)) = 1) for i in 1:memsize[]]...)

      n_matches = 0
      # Backtracking stack
      stack_idx = 0

      # Instruction 0 is used to return when  the backtracking stack is empty. 
      # We start from 1.
      stack_idx += 1
      stack[stack_idx] = 0x0000
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
        # begin
        # println("σ = ", [$([:($(Symbol(:σ, i))) for i in 1:memsize[]]...)])
        # println("CURRENT PC = $pc")
        if pc === $(UInt16(i))
          $code
        end
        # end
      ) for (i, code) in enumerate(program)]...)

      error("unreachable code!")

      @label backtrack
      # @show "BACKTRACKING"
      # @show stack
      pc = stack[stack_idx]
      stack_idx -= 1

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

ematch_compile_ground!(addr, ground_terms_to_addr, program, memsize, ::AbstractPat) = nothing

# Ground e-matchers
function ematch_compile_ground!(addr, ground_terms_to_addr, program, memsize, pattern::Union{PatExpr,PatLiteral})
  if haskey(ground_terms_to_addr, pattern)
    return
  end

  if isground(pattern)
    # Remember that it has been searched and its stored in σaddr
    ground_terms_to_addr[pattern] = addr
    # Add the lookup instruction to the program
    push!(program, lookup_expr(addr, pattern))
    # Memory needs one more register 
    memsize[] += 1
  else
    # Search for ground patterns in the children.
    for child_pattern in children(pattern)
      ematch_compile_ground!(memsize[], ground_terms_to_addr, program, memsize, child_pattern)
    end
  end
end

# ==============================================================
# Term E-Matchers
# ==============================================================

function ematch_compile!(addr, ground_terms_to_addr, patvar_to_addr, program, memsize, pattern::PatExpr)
  if haskey(ground_terms_to_addr, pattern)
    push!(program, check_eq_expr(addr, ground_terms_to_addr[pattern]))
    return
  end

  c = memsize[]
  nargs = arity(pattern)
  memrange = c:(c + nargs - 1)
  memsize[] += nargs

  push!(program, bind_expr(addr, pattern, memrange))
  for (i, child_pattern) in enumerate(arguments(pattern))
    ematch_compile!(memrange[i], ground_terms_to_addr, patvar_to_addr, program, memsize, child_pattern)
  end
end


function ematch_compile!(addr, ground_terms_to_addr, patvar_to_addr, program, memsize, patvar::PatVar)
  instruction = if patvar_to_addr[patvar.idx] != -1
    # Pattern variable with the same Debrujin index has appeared in the  
    # pattern before this. Just check if the current e-class id matches the one 
    # That was already encountered.
    check_eq_expr(addr, patvar_to_addr[patvar.idx])
  else
    # Variable has not been seen before. Store its memory address
    patvar_to_addr[patvar.idx] = addr
    # insert instruction for checking predicates or type.
    check_var_expr(addr, patvar.predicate)
  end
  push!(program, instruction)
end

function ematch_compile!(addr, ground_terms_to_addr, patvar_to_addr, program, memsize, ::AbstractPat)
  # Pattern not supported.
  push!(program, :(println("NOT SUPPORTED"); return 0))
end


function ematch_compile!(addr, ground_terms_to_addr, patvar_to_addr, program, memsize, literal::PatLiteral)
  push!(program, check_eq_expr(addr, ground_terms_to_addr[literal]))
end


# ==============================================================
# Actual Instructions
# ==============================================================

function bind_expr(addr, p::PatExpr, memrange)
  quote
    eclass = g[$(Symbol(:σ, addr))]
    eclass_length = length(eclass.nodes)
    if $(Symbol(:enode_idx, addr)) <= eclass_length
      stack_idx += 1
      @assert stack_idx <= length(stack)
      stack[stack_idx] = pc

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
    eclass = g[$(Symbol(:σ, addr))]
    for (j, n) in enumerate(eclass.nodes)
      if !v_isexpr(n)
        $(Symbol(:enode_idx, addr)) = j + 1
        break
      end
    end
    pc += 0x0001
    @goto compute
  end
end

function check_var_expr(addr, predicate::Function)
  quote
    eclass = g[$(Symbol(:σ, addr))]
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
    eclass = g[$(Symbol(:σ, addr))]
    eclass_length = length(eclass.nodes)
    if $(Symbol(:enode_idx, addr)) <= eclass_length
      stack_idx += 1
      @assert stack_idx <= length(stack)
      stack[stack_idx] = pc

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
    ecid = Metatheory.EGraphs.lookup_pat(g, $p)
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
    :(push!(g.buffer_new, v_pair($(Symbol(:σ, addr)), reinterpret(UInt64, $(Symbol(:enode_idx, addr)) - 1)))) for
    addr in patvar_to_addr
  ]
  quote
    g.needslock && lock(g.lock)
    push!(g.buffer_new, v_pair(root_id, reinterpret(UInt64, rule_idx * $direction)))
    $(push_exprs...)
    # Add delimiter to buffer. 
    push!(g.buffer_new, 0xffffffffffffffffffffffffffffffff)
    n_matches += 1
    g.needslock && unlock(g.lock)
    @goto backtrack
  end
end

