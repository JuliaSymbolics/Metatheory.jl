# Full e-matcher
function ematch_compile(p, direction)
  pvars = patvars(p)
  setdebrujin!(p, pvars)

  npvars = length(pvars)

  patvar_to_addr = fill(-1, npvars)
  ground_terms_to_addr = Dict{Any,Int}()

  program = Expr[]
  memsize = Ref(1)

  ematch_compile_ground!(1, ground_terms_to_addr, program, memsize, p)
  first_nonground = memsize[]
  memsize[] += 1

  ematch_compile!(first_nonground, ground_terms_to_addr, patvar_to_addr, program, memsize, p)

  push!(program, yield_expr(patvar_to_addr, direction))

  quote
    function ($(gensym("ematcher")))(g::EGraph, rule_idx::Int, root_id::Id)::Int
      # Copy and empty the memory 
      $(make_memory(memsize[], first_nonground)...)
      $([:($(Symbol(:enode_idx, i)) = 1) for i in 1:memsize[]]...)

      n_matches = 0
      # Backtracking stack
      stack = Int[]
      # Instruction 0 is used to return when  the backtracking stack is empty. 
      # We start from 1.
      push!(stack, 0)
      pc = 1

      # We goto this label when:
      # 1) After backtracking, the pc is popped from the stack.
      # 2) When an instruction succeeds, the pc is incremented.  
      @label compute
      # Instruction 0 is used to return when  the backtracking stack is empty. 
      pc == 0 && return n_matches

      # For each instruction in the program, create an if statement, 
      # Checking if the current value 
      $([:(
        begin
          # println("σ = ", [$([:($(Symbol(:σ, i))) for i in 1:memsize[]]...)])
          # println("CURRENT PC = $pc")
          if pc == $i
            $code
          end
        end
      ) for (i, code) in enumerate(program)]...)

      error("unreachable code!")

      @label backtrack
      # @show "BACKTRACKING"
      # @show stack
      pc = pop!(stack)
      @goto compute

      return -1
    end
  end
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

function ematch_compile_ground!(addr, ground_terms_to_addr, program, memsize, p::Any)
  if !haskey(ground_terms_to_addr, p)
    # If the instruction for searching the constant literal
    # has not already been inserted in the program: 
    # Remember that it has been searched and its stored in σaddr
    ground_terms_to_addr[p] = addr
    # Add the lookup instruction to the program
    push!(program, lookup_expr(addr, p))
    memsize[] += 1
  end
end

ematch_compile_ground!(addr, ground_terms_to_addr, program, memsize, pattern::AbstractPat) = nothing

# Ground e-matchers
function ematch_compile_ground!(addr, ground_terms_to_addr, program, memsize, pattern::PatExpr)
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
    @show ground_terms_to_addr pattern
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

function ematch_compile!(addr, ground_terms_to_addr, patvar_to_addr, program, memsize, literal)
  push!(program, check_eq_expr(addr, ground_terms_to_addr[literal]))
end

function ematch_compile!(addr, ground_terms_to_addr, patvar_to_addr, program, memsize, pattern::AbstractPattern)
  throw(DomainError(pattern, "Pattern not supported in e-graph pattern matching."))
end


# ==============================================================
# Actual Instructions
# ==============================================================

function bind_expr(addr, p::PatExpr, memrange)
  quote
    eclass = g[$(Symbol(:σ, addr))]
    eclass_length = length(eclass.nodes)
    if $(Symbol(:enode_idx, addr)) <= eclass_length
      push!(stack, pc)

      n = eclass.nodes[$(Symbol(:enode_idx, addr))]

      v_flags(n) == $(v_flags(p.n)) || @goto $(Symbol(:skip_node, addr))
      v_signature(n) == $(v_signature(p.n)) || @goto $(Symbol(:skip_node, addr))
      v_head(n) == $(v_head(p.n)) || (v_head(n) == $(p.quoted_head_hash) || @goto $(Symbol(:skip_node, addr)))

      # Node has matched.
      $([:($(Symbol(:σ, j)) = v_children(n)[$i]) for (i, j) in enumerate(memrange)]...)
      pc += 1
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
    # TODO bind first literal enode index 
    pc += 1
    @goto compute
  end
end

function check_var_expr(addr, predicate::Function)
  quote
    eclass = g[$(Symbol(:σ, addr))]
    if ($predicate)(g, eclass)
      # TODO bind first literal enode index 
      pc += 1
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
      push!(stack, pc)

      n = eclass.nodes[$(Symbol(:enode_idx, addr))]

      if !v_isexpr(n)
        hn = Metatheory.EGraphs.get_constant(g, v_head(n))
        if hn isa $T
          $(Symbol(:enode_idx, addr)) += 1
          pc += 1
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
      pc += 1
      @goto compute
    else
      @goto backtrack
    end
  end
end

function lookup_expr(addr, p)
  quote
    ecid = Metatheory.EGraphs.lookup_pat(g, $p)
    if ecid > 0
      $(Symbol(:σ, addr)) = ecid
      pc += 1
      @goto compute
    end
    @goto backtrack
  end
end

function yield_expr(patvar_to_addr, direction)
  # makedict = [
  #   :(b = Metatheory.assoc(b, $i, ($(Symbol(:σ, addr)), $(Symbol(:enode_idx, addr))))) for
  #   (i, addr) in enumerate(patvar_to_addr)
  # ]
  push_exprs = [
    :(push!(g.buffer_new, v_pair($(Symbol(:σ, addr)), reinterpret(UInt64, $(Symbol(:enode_idx, addr)))))) for
    addr in patvar_to_addr
  ]
  quote
    g.needslock && lock(g.buffer_lock)
    b = Metatheory.Bindings()
    # push!(g.buffer, Metatheory.assoc(b, 0, (root_id, rule_idx * $direction)))
    push!(g.buffer_new, v_pair(root_id, reinterpret(UInt64, rule_idx * $direction)))
    $(push_exprs...)
    # Add delimiter to buffer. 
    push!(g.buffer_new, 0xffffffffffffffffffffffffffffffff)
    n_matches += 1
    g.needslock && unlock(g.buffer_lock)
    @goto backtrack
  end
end

# ==============================================================
# ==============================================================
# ==============================================================

# DEMO

quote
  function ematch_compiler()
    is_var_bound = fill(false, npvars)
    quote
      function ematch_rule()::Int
        n_matches = 0
        stack = Int[]
        push!(stack, 0)
        pc = 1
        options = fill(1, 3)

        @label compute

        if pc == 0
          # Return 
          return n_matches
        elseif pc == 1
          # instead of for loop
          if options[1] < num_options_1
            push!(stack, 1)
            if matches(aa)
              options[1] += 1
              pc += 1
              @goto compute
            end
            options[1] += 1
            @goto backtrack
          end
          options[1] = 1 # restart from first option
          @goto backtrack
        elseif pc == 2
          bbb
        elseif pc == 3
          println("success!")
          @goto backtrack
        end

        @label backtrack
        pc = pop!(stack)
        @goto compute
      end
    end
  end
end