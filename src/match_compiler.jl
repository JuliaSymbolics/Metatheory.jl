using Metatheory: alwaystrue
using TermInterface

@kwdef mutable struct MatchCompilerState
  pvars_bound::Vector{Bool}
  program::Vector{Expr} = Expr[]
  term_coord_variables = Pair{Symbol,Any}[]
  segments::Vector{Symbol} = Symbol[]
  current_term_has_segment::Bool = false
  current_term_n_remaining::Int = 0
end

function match_compile(p::AbstractPat, pvars)
  npvars = length(pvars)

  state = MatchCompilerState(; pvars_bound = fill(false, npvars))

  # Tree cordinates are a vector of integers.
  # Each index `i` in the vector corresponds to the depth of the term 
  # Each value `n` at index `i` selects the `n`-th children of the term at depth i
  # Example: in f(x, g(y, k, h(z))), to get z the coordinate is [2,3,1]
  coordinate = Int[]

  match_compile!(p, state, coordinate, Symbol[])
  push!(state.program, :(return callback($(pvars...))))

  quote
    Base.@propagate_inbounds function ($(gensym("matcher")))(t, callback::Function, stack::OptBuffer{UInt16})
      # Assign and empty the variables for patterns 
      $([:($var = nothing) for var in pvars]...)

      # Initialize the variables needed in the outermost scope (accessible by instruction blocks)
      $([:($(Symbol(k)) = $v) for (k, v) in state.term_coord_variables]...)

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
      # Instruction 0 is used to fail the backtracking stack is empty. 
      pc === 0x0000 && return nothing

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
    end
  end
end

# ==============================================================
# Term Matchers
# ==============================================================

function make_coord_symbol(coordinate)
  isempty(coordinate) && return :t
  Symbol("t_", join(coordinate, "_"))
end

function get_coord(coordinate, current_term_has_segment = false)
  isempty(coordinate) && return :t

  tsym = make_coord_symbol(coordinate[1:(end - 1)])
  idx = if current_term_has_segment
    :($(last(coordinate)) + $(Symbol(tsym, :_offset)))
  else
    last(coordinate)
  end
  :($(Symbol(tsym, :_args))[$idx])
end

function match_compile!(pattern::PatExpr, state::MatchCompilerState, coordinate::Vector{Int}, parent_segments)
  push!(state.program, match_term_expr(pattern, coordinate, state.current_term_has_segment))
  t_sym = make_coord_symbol(coordinate)
  !isempty(coordinate) && push!(state.term_coord_variables, t_sym => nothing)
  push!(state.term_coord_variables, Symbol(t_sym, :_op) => nothing)
  push!(state.term_coord_variables, Symbol(t_sym, :_args) => nothing)
  # The sum of how many terms have been taken by segments

  state.current_term_has_segment = false

  p_args = arguments(pattern)
  p_arity = length(p_args)
  state.current_term_n_remaining = 0

  segments_so_far = Symbol[]

  for (i, child_pattern) in enumerate(p_args)
    @show p_arity i
    state.current_term_n_remaining = p_arity - i
    match_compile!(child_pattern, state, [coordinate; i], segments_so_far)
  end

  state.current_term_has_segment && push!(state.term_coord_variables, Symbol(t_sym, :_offset) => 0)

  state.current_term_has_segment = false
end


function match_compile!(
  patvar::Union{PatVar,PatSegment},
  state::MatchCompilerState,
  coordinate::Vector{Int},
  parent_segments,
)
  # Mark that the current term has a segment variable
  instruction = if state.pvars_bound[patvar.idx]
    # Pattern variable with the same Debrujin index has appeared in the  
    # pattern before this (is bound). Just check for equality.
    match_eq_expr(patvar, coordinate, state.current_term_has_segment)
  else
    # Variable has not been seen before. Store it
    state.pvars_bound[patvar.idx] = true
    # insert instruction for checking predicates or type.
    match_var_expr(patvar, state, coordinate, parent_segments)
  end
  if patvar isa PatSegment
    state.current_term_has_segment = true
    push!(state.term_coord_variables, Symbol(patvar.name, :_n_dropped) => 0)
    push!(parent_segments, patvar.name)
  end
  push!(state.program, instruction)
end


function match_compile!(p::PatLiteral, state::MatchCompilerState, coordinate::Vector{Int}, parent_segments)
  push!(state.program, match_eq_expr(p, coordinate, state.current_term_has_segment))
end

function match_compile!(p::AbstractPat, state::MatchCompilerState, coordinate::Vector{Int}, parent_segments)
  # Pattern not supported.
  @show p
  push!(state.program, :(error("NOT SUPPORTED"); return 0))
end




# ==============================================================
# Actual Instructions
# ==============================================================

function match_term_expr(pattern::PatExpr, coordinate, current_term_has_segment)
  t = make_coord_symbol(coordinate)
  op_fun = iscall(pattern) ? :operation : :head
  args_fun = iscall(pattern) ? :arguments : :children

  op_pat = operation(pattern)
  op_guard = if op_pat isa Union{Function,DataType}
    :($(Symbol(t, :_op)) == $(pattern.head) || $(Symbol(t, :_op)) == $(QuoteNode(pattern.quoted_head)) || @goto backtrack)
  elseif op_pat isa Union{Symbol,Expr}
    :($(Symbol(t, :_op)) == $(QuoteNode(pattern.head)) || @goto backtrack)
  end

  @show pattern
  quote
    $t = $(get_coord(coordinate, current_term_has_segment))

    @show t
    isexpr($t) || @goto backtrack

    @show "DAJE"
    iscall($t) === $(iscall(pattern)) || @goto backtrack

    $(Symbol(t, :_op)) = $(op_fun)($t)
    $(Symbol(t, :_args)) = $(args_fun)($t)

    $op_guard

    pc += 0x0001
    @goto compute
  end
end

match_var_expr_if_guard(patvar::Union{PatVar,PatSegment}, predicate::Function) = :($(predicate)($patvar.name))
match_var_expr_if_guard(patvar::Union{PatVar,PatSegment}, predicate::typeof(alwaystrue)) = true
match_var_expr_if_guard(patvar::Union{PatVar,PatSegment}, T::Type) = :($(patvar.name) isa $T)


function match_var_expr(patvar::PatVar, state::MatchCompilerState, coordinate, segments_so_far)
  quote
    $(patvar.name) = $(get_coord(coordinate, state.current_term_has_segment))
    if $(match_var_expr_if_guard(patvar, patvar.predicate))
      pc += 0x0001
      @goto compute
    end
    @goto backtrack
  end
end

function match_var_expr(patvar::PatSegment, state::MatchCompilerState, coordinate, segments_so_far)
  tsym = make_coord_symbol(coordinate[1:(end - 1)])
  tsym_args = Symbol(tsym, :_args)
  offset_sym = Symbol(tsym, :_offset)
  n_dropped_sym = Symbol(patvar.name, :_n_dropped)

  start_idx = if state.current_term_has_segment
    :($(last(coordinate)) + $offset_sym)
  else
    last(coordinate)
  end

  offset_so_far = foldl((x, y) -> :($x + $y), map(n -> :(length($n)), segments_so_far); init = 0)

  @show offset_so_far

  quote
    start_idx = $start_idx
    end_idx = length($tsym_args) - $(state.current_term_n_remaining)

    @show $(state.current_term_n_remaining)
    @show length($tsym_args)

    @show $offset_sym
    @show start_idx end_idx $n_dropped_sym

    if end_idx - $n_dropped_sym >= start_idx - 1
      push!(stack, pc)

      $(patvar.name) = view($tsym_args, start_idx:(end_idx - $n_dropped_sym))

      @show start_idx
      @show $tsym_args
      @show $(patvar.name)

      @show length($(patvar.name))
      $offset_sym = length($(patvar.name)) + $offset_so_far - 1

      @show $offset_sym

      $n_dropped_sym += 1

      if $offset_sym + $(state.current_term_n_remaining) >= length($tsym_args)
        @goto backtrack
      end

      if $(match_var_expr_if_guard(patvar, patvar.predicate))
        pc += 0x0001
        @goto compute
      end

      @goto backtrack
    end

    # Restart 
    $n_dropped_sym = 0
    @goto backtrack
  end
end



function match_eq_expr(patvar::PatVar, coordinate, current_term_has_segment)
  quote
    if $(patvar.name) == $(get_coord(coordinate, current_term_has_segment))
      pc += 0x0001
      @goto compute
    else
      @goto backtrack
    end
  end
end

function match_eq_expr(pat::PatLiteral, coordinate, current_term_has_segment)
  quote
    @show $(QuoteNode(get_coord(coordinate, current_term_has_segment)))
    if $(pat.value) == $(get_coord(coordinate, current_term_has_segment))
      pc += 0x0001
      @goto compute
    else
      @goto backtrack
    end
  end
end