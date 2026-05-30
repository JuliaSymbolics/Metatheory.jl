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
  This vector stores the σ variable index (address) for that variable at position i.
  Sentinel -2 marks a segment patvar (no σ; uses segment_patvar_syms instead).
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

  """
  Maps de Bruijn index of a segment patvar → local Symbol for its seg_buf offset.
  E.g., de Bruijn index 2 → :seg_offset_2
  """
  segment_patvar_syms::Dict{Int,Symbol} = Dict{Int,Symbol}()
end

"""
Build a single `if pc === 1 elseif pc === 2 ... else error end` chain from the
instruction list. A contiguous if/elseif chain is reliably lowered by LLVM into a
jump table (switch instruction), whereas independent `if` blocks are not.
"""
function build_dispatch_chain(program::Vector{Expr})
  n = length(program)
  isempty(program) && return :(error("empty ematcher program"))

  # Build inside-out: last elseif first
  unreachable = :(error("ematcher: unreachable instruction"))
  tail = Expr(:elseif, :(pc === $(UInt16(n))), program[n], unreachable)
  for i in (n - 1):-1:2
    tail = Expr(:elseif, :(pc === $(UInt16(i))), program[i], tail)
  end

  n == 1 ? Expr(:if, :(pc === $(UInt16(1))), program[1], unreachable) :
           Expr(:if, :(pc === $(UInt16(1))), program[1], tail)
end

function ematch_compile(p, pvars, direction)
  # Create the compiler state with the right number of pattern variables
  state = EMatchCompilerState(; patvar_to_addr = fill(-1, length(pvars)))

  ematch_compile_ground!(p, state, 1)

  state.first_nonground = state.memsize
  state.memsize += 1

  ematch_compile!(p, state, state.first_nonground)

  push!(state.program, yield_expr(state.patvar_to_addr, state.segment_patvar_syms, direction))

  pat_constants_checks = check_constant_exprs!(Expr[], p)

  # Declare local variables for segment buffer offsets (one per segment patvar).
  # Initialized to typemax(UInt64) = "no previous push" sentinel.
  seg_offset_decls = [:($(sym) = typemax(UInt64)) for (_, sym) in state.segment_patvar_syms]

  # literal_hash locals: only for non-segment patvars (addr > 0)
  lit_hash_decls = [:($(Symbol(:literal_hash, i)) = UInt64(0)) for i in state.patvar_to_addr if i > 0]

  quote
    function ($(gensym("ematcher")))(
      g::$(Metatheory.EGraphs.EGraph),
      rule_idx::Int,
      root_id::$(Metatheory.Id),
      stack::$(Metatheory.OptBuffer){UInt16},
      ematch_buffer::$(Metatheory.OptBuffer){UInt64},
      seg_buf::$(Metatheory.OptBuffer){UInt64} = $(Metatheory.OptBuffer){UInt64}(0);
      limit::$(Int)=$(typemax(Int))
    )::Int
      iszero(limit) && return 0 # return immediately when no matches are allowed
      # If the constants in the pattern are not all present in the e-graph, just return 
      $(pat_constants_checks...)
      # Initialize σ variables (e-classes memory) and enode iteration indexes
      $(make_memory(state.memsize, state.first_nonground)...)
      # Each node in the pattern can store an index of an enode to iterate the e-classes
      $([:($(Symbol(:enode_idx, i)) = 1) for i in state.enode_idx_addresses]...)
      # Each non-segment pattern variable can yield a literal hash
      $(lit_hash_decls...)
      # Segment patvar offset locals: typemax = "no prior push" sentinel
      $(seg_offset_decls...)

      n_matches = 0
      # Backtracking stack
      stack_idx = 0

      # Bit i set when pattern variable i bound to a literal hash (not an e-class id).
      isliteral_bitvec = UInt64(0)

      # Instruction 0 is used to return when  the backtracking stack is empty.
      # We start from 1.
      empty!(stack)
      push!(stack, 0x0000)
      pc = 0x0001

      # We goto this label when:
      # 1) After backtracking, the pc is popped from the stack.
      # 2) When an instruction succeeds, the pc is incremented.
      @label compute
      # Instruction 0 is used to return when the backtracking stack is empty.
      pc === 0x0000 && return n_matches
      if n_matches >= limit
        empty!(stack)
        return n_matches
      end

      # Dispatch to the current instruction via an if/elseif chain.
      # A single chain (not independent if blocks) lets LLVM recognise the switch
      # pattern and emit a jump table instead of a linear sequence of comparisons.
      $(build_dispatch_chain(state.program))

      @label backtrack
      pc = pop!(stack)

      @goto compute

      return -1
    end
  end
end

"""Emit early `return 0` checks when ground constants from `pat` are absent from the e-graph."""
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
# A ground term has no pattern variables: it is matched once via `lookup_pat` and stored in σ.
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
  elseif p.type === PAT_SEGMENT
    # Segments are only valid as children of PAT_EXPR; reaching here is a bug or invalid pattern.
    push!(
      state.program,
      :(throw(DomainError($(QuoteNode(p.name)), "Segment variable ~~$(p.name) cannot appear at the root of an e-graph pattern")); return 0),
    )
  end
end

function ematch_compile_expr!(p::Pat, state::EMatchCompilerState, addr::Int)
  @assert p.type === PAT_EXPR

  if haskey(state.ground_terms_to_addr, p)
    push!(state.program, check_eq_expr(addr, state.ground_terms_to_addr[p]))
    return
  end

  # Route to segment variant when any immediate child is a segment variable
  if p.has_segment_children
    ematch_compile_segment_expr!(p, state, addr)
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


"""
Compile a PAT_EXPR that contains exactly one segment child (~~x).
Supports any mix of fixed-arity children before and after the segment.
Multiple segments within a single expression are not supported.
"""
function ematch_compile_segment_expr!(p::Pat, state::EMatchCompilerState, addr::Int)
  @assert p.type === PAT_EXPR

  # Locate the single segment child
  seg_positions = findall(c -> c.type === PAT_SEGMENT, p.children)
  if length(seg_positions) != 1
    push!(
      state.program,
      :(throw(DomainError(nothing, "E-graph matching requires exactly one segment variable per expression; got $(length($seg_positions))")); return 0),
    )
    return
  end

  seg_child_pos = only(seg_positions)   # 1-based position in p.children
  seg_pat = p.children[seg_child_pos]

  n_prefix = seg_child_pos - 1               # fixed children before segment
  n_suffix = length(p.children) - seg_child_pos  # fixed children after segment
  n_min    = n_prefix + n_suffix             # minimum e-node arity to match

  # Allocate σ addresses for fixed children (non-segment), in order
  fixed_children = [p.children[i] for i in eachindex(p.children) if i != seg_child_pos]
  n_fixed = length(fixed_children)
  c = state.memsize
  state.memsize += n_fixed
  fixed_addr_range = c:(c + n_fixed - 1)

  # Register segment patvar: mark with sentinel -2, create a unique local symbol
  seg_dbi = seg_pat.idx
  if state.patvar_to_addr[seg_dbi] == -2
    # Repeated segment variable — not yet supported
    push!(
      state.program,
      :(throw(DomainError($(QuoteNode(seg_pat.name)), "Repeated segment variable ~~$(seg_pat.name) in one e-graph pattern is not yet supported")); return 0),
    )
    return
  end
  state.patvar_to_addr[seg_dbi] = -2
  seg_offset_sym = Symbol(:seg_offset_, seg_dbi)
  state.segment_patvar_syms[seg_dbi] = seg_offset_sym

  push!(state.enode_idx_addresses, addr)

  # Emit the segment bind instruction
  push!(state.program, bind_segment_expr(addr, p, fixed_addr_range, seg_offset_sym, n_prefix, n_suffix, n_min))

  # Compile each fixed child at its allocated σ address
  fixed_slot = 1
  for (ci, child_p) in enumerate(p.children)
    ci == seg_child_pos && continue  # handled by bind_segment_expr
    ematch_compile!(child_p, state, fixed_addr_range[fixed_slot])
    fixed_slot += 1
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

      n = @inbounds eclass.nodes[$(Symbol(:enode_idx, addr))]

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

"""
Bind instruction for a PAT_EXPR containing one segment variable.

On each entry (including re-entries after backtracking), restores `seg_buf` to its
pre-push position using the `typemax(UInt64)` sentinel protocol:
  - `typemax(UInt64)` means "no previous push at this level" (first entry or after exhaustion).
  - Any other value is the `seg_buf.i` saved before the previous successful push.

# EXPENSIVE: this instruction iterates all e-nodes in an e-class and writes to seg_buf.
# Called once per candidate e-class per iteration. Cost is proportional to eclass size.
"""
function bind_segment_expr(
  addr::Int, p::Pat, fixed_addr_range, seg_offset_sym::Symbol,
  n_prefix::Int, n_suffix::Int, n_min::Int,
)
  # Assignment expressions for fixed prefix children:
  #   σ[fixed_addr_range[i]] = n.data[VECEXPR_META_LENGTH + i]  for i in 1:n_prefix
  prefix_assigns = [
    :($(Symbol(:σ, fixed_addr_range[i])) = n.data[$(VECEXPR_META_LENGTH + i)])
    for i in 1:n_prefix
  ]

  # Assignment expressions for fixed suffix children (from end of e-node):
  #   σ[fixed_addr_range[n_prefix+i]] = n.data[length(n.data) - (n_suffix - i)]
  #   i=1,n_suffix=1 → n.data[length-0] = last child  ✓
  #   i=1,n_suffix=2 → n.data[length-1] = penultimate  ✓
  suffix_assigns = [
    :($(Symbol(:σ, fixed_addr_range[n_prefix + i])) = n.data[length(n.data) - $(n_suffix - i)])
    for i in 1:n_suffix
  ]

  # Segment data loop: children at positions n_prefix+1 .. arity-n_suffix (1-indexed).
  # In n.data those are indices VECEXPR_META_LENGTH+n_prefix+1 .. length(n.data)-n_suffix.
  seg_start_data_idx = VECEXPR_META_LENGTH + n_prefix + 1

  quote
    # --- Buffer restore protocol ---
    # On re-entry after backtracking: typemax sentinel absent → restore to pre-push position,
    # undoing this segment's data AND any inner segment data pushed after it.
    if $(seg_offset_sym) != typemax(UInt64)
      seg_buf.i = Int($(seg_offset_sym))
    end

    eclass = g[$(Symbol(:σ, addr))]
    eclass_length = length(eclass.nodes)
    if $(Symbol(:enode_idx, addr)) <= eclass_length
      push!(stack, pc)

      n = @inbounds eclass.nodes[$(Symbol(:enode_idx, addr))]
      $(Symbol(:enode_idx, addr)) += 1

      # Check flags, head, and minimum required arity
      v_flags(n) === $(v_flags(p.n)) || @goto $(Symbol(:skip_seg_node, addr))
      v_head(n) === $(v_head(p.n)) || (v_head(n) === $(p.name_hash) || @goto $(Symbol(:skip_seg_node, addr)))
      v_arity(n) >= $n_min || @goto $(Symbol(:skip_seg_node, addr))

      # Assign fixed prefix children
      $(prefix_assigns...)

      # Save pre-push position, then write [seg_len, child_ids...] to seg_buf.
      # Uses push_many! for a single unsafe_copyto! instead of per-element pushes.
      $(seg_offset_sym) = UInt64(length(seg_buf))
      let seg_len = v_arity(n) - $n_min
        push!(seg_buf, UInt64(seg_len))
        Metatheory.push_many!(seg_buf, n.data, $seg_start_data_idx, length(n.data) - $n_suffix)
      end

      # Assign fixed suffix children (read from end of data array)
      $(suffix_assigns...)

      pc += 0x0001
      @goto compute

      @label $(Symbol(:skip_seg_node, addr))
      @goto backtrack
    end

    # All nodes exhausted: reset enode index and sentinel for clean re-entry.
    $(Symbol(:enode_idx, addr)) = 1
    $(seg_offset_sym) = typemax(UInt64)
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
    isliteral_bitvec = v_bitvec_clear(isliteral_bitvec, $idx)
    $(Symbol(:literal_hash, addr)) = UInt64(0)
    if ($predicate)(g, eclass)
      # @debug "$eclass matches predictate"
      for (j, n) in enumerate(eclass.nodes)
        if !v_isexpr(n)
          # @debug "found literal node at index $j"
          $(Symbol(:enode_idx, addr)) = j + 1
          # $(Symbol(:literal_hash, addr)) = v_head(n)
          # isliteral_bitvec = v_bitvec_set(isliteral_bitvec, $idx)
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
      n = @inbounds eclass.nodes[$(Symbol(:enode_idx, addr))]

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

      # This node did not match. Try next node; clear stale literal state for this variable.
      isliteral_bitvec = v_bitvec_clear(isliteral_bitvec, $idx)
      $(Symbol(:literal_hash, addr)) = UInt64(0)
      $(Symbol(:enode_idx, addr)) += 1
      @goto backtrack
    end

    # Restart from first option
    isliteral_bitvec = v_bitvec_clear(isliteral_bitvec, $idx)
    $(Symbol(:literal_hash, addr)) = UInt64(0)
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

"""
Yield instruction: push one match record to `ematch_buffer`.

Record layout (N = number of patvars):
  [root_id, signed_rule_idx, isliteral_bitvec, binding_1, ..., binding_N]

For regular patvars: binding_i = e-class ID or literal hash (as before).
For segment patvars: binding_i = offset into rule.segment_buffer where
  [seg_len, child_id_1, ..., child_id_seg_len] is stored.
"""
function yield_expr(patvar_to_addr, segment_patvar_syms::Dict{Int,Symbol}, direction::Int)
  push_exprs = map(enumerate(patvar_to_addr)) do (i, addr)
    if addr == -2
      # Segment patvar: push the buffer offset stored in the local seg_offset symbol
      seg_sym = segment_patvar_syms[i]
      :(push!(ematch_buffer, $(seg_sym)))
    else
      # Regular patvar: push e-class ID or literal hash
      :(push!(
        ematch_buffer,
        v_bitvec_check(isliteral_bitvec, $i) ? $(Symbol(:literal_hash, addr)) : $(Symbol(:σ, addr)),
      ))
    end
  end
  quote
    g.needslock && lock(g.lock)
    push!(ematch_buffer, root_id)
    push!(ematch_buffer, reinterpret(UInt64, rule_idx * $direction))
    push!(ematch_buffer, isliteral_bitvec)

    $(push_exprs...)
    g.needslock && unlock(g.lock)
    n_matches += 1
    @goto backtrack
  end
end
