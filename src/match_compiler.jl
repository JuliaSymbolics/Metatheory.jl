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
    function ($(gensym("matcher")))(t, callback::Function, stack::OptBuffer{UInt16})
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

_offset_so_far(segments) = foldl((x, y) -> :($x + $y), map(n -> :(length($n) - 1), segments); init = 0)


function get_coord(coordinate, segments_so_far)
  isempty(coordinate) && return :t

  tsym = make_coord_symbol(coordinate[1:(end - 1)])
  :($(Symbol(tsym, :_args))[$(get_idx(coordinate, segments_so_far))])
end

get_idx(coordinate, segments_so_far) = :($(last(coordinate)) + $(_offset_so_far(segments_so_far)))

function match_compile!(pattern::PatExpr, state::MatchCompilerState, coordinate::Vector{Int}, parent_segments)
  push!(state.program, match_term_expr(pattern, coordinate, parent_segments))
  t_sym = make_coord_symbol(coordinate)
  !isempty(coordinate) && push!(state.term_coord_variables, t_sym => nothing)
  push!(state.term_coord_variables, Symbol(t_sym, :_op) => nothing)
  push!(state.term_coord_variables, Symbol(t_sym, :_args) => nothing)
  # The sum of how many terms have been taken by segments


  p_args = arguments(pattern)
  p_arity = length(p_args)
  state.current_term_n_remaining = 0

  segments_so_far = Symbol[]

  for (i, child_pattern) in enumerate(p_args)
    @show p_arity i
    state.current_term_n_remaining = p_arity - i - count(x -> (x isa PatSegment), @view(p_args[(i + 1):end]))
    match_compile!(child_pattern, state, [coordinate; i], segments_so_far)
  end
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
    match_eq_expr(patvar, state, coordinate, parent_segments)
  else
    # Variable has not been seen before. Store it
    state.pvars_bound[patvar.idx] = true
    # insert instruction for checking predicates or type.
    match_var_expr(patvar, state, coordinate, parent_segments)
  end
  if patvar isa PatSegment
    push!(parent_segments, patvar.name)
    push!(state.term_coord_variables, Symbol(patvar.name, :_n_dropped) => 0)
  end
  push!(state.program, instruction)
end


function match_compile!(p::PatLiteral, state::MatchCompilerState, coordinate::Vector{Int}, segments_so_far)
  push!(state.program, match_eq_expr(p, state, coordinate, segments_so_far))
end

# ==============================================================
# Actual Instructions
# ==============================================================

function match_term_expr(pattern::PatExpr, coordinate, segments_so_far)
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
    $t = $(get_coord(coordinate, segments_so_far))

    # @show t
    isexpr($t) || @goto backtrack

    # @show "DAJE"
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
    $(patvar.name) = $(get_coord(coordinate, segments_so_far))
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
  n_dropped_sym = Symbol(patvar.name, :_n_dropped)


  # Counts how many terms have been matched by segments in the current variable.
  # TODO optimize, move to function
  offset_so_far = _offset_so_far(segments_so_far)

  @show offset_so_far

  quote
    @show "matching $($(patvar))"

    start_idx = $(get_idx(coordinate, segments_so_far))
    @show start_idx
    end_idx = length($tsym_args) - $(state.current_term_n_remaining)


    @show $tsym_args
    @show $(state.current_term_n_remaining)
    @show length($tsym_args)

    @show start_idx end_idx $n_dropped_sym

    if end_idx - $n_dropped_sym >= start_idx - 1
      push!(stack, pc)

      $(patvar.name) = view($tsym_args, start_idx:(end_idx - $n_dropped_sym))

      @show start_idx $tsym_args $(patvar.name) length($(patvar.name))


      @show $(state.current_term_n_remaining)

      # if $offset_sym + $(state.current_term_n_remaining) >= length($tsym_args)
      #   @show "PORCODDIOOOOOOOOOOOOOOO"
      #   @goto backtrack
      # end


      $n_dropped_sym += 1

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



function match_eq_expr(patvar::PatVar, state::MatchCompilerState, coordinate, segments_so_far)
  quote
    if $(patvar.name) == $(get_coord(coordinate, segments_so_far))
      pc += 0x0001
      @goto compute
    else
      @goto backtrack
    end
  end
end


function match_eq_expr(patvar::PatSegment, state::MatchCompilerState, coordinate, segments_so_far)
  # This method should be called only when a PatSegment is already bound.
  # Get parent term variable name
  # TODO reuse in function, duplicate from get_coord 
  tsym = make_coord_symbol(coordinate[1:(end - 1)])
  tsym_args = Symbol(tsym, :_args)

  start_idx = get_idx(coordinate, segments_so_far)

  # Counts how many terms have been matched by segments in the current variable.
  # TODO optimize, move to function
  @show segments_so_far
  offset_so_far = foldl((x, y) -> :($x + $y), map(n -> :(length($n) - 1), segments_so_far); init = 0)

  quote
    @show "matching APPEARED AGAIN $($(patvar.name))"

    if $start_idx > length($tsym_args)
      @show "PORCA MADONNA"
      @goto backtrack
    end

    @show $tsym_args

    for i in 1:length($(patvar.name))
      @show i
      @show ($tsym_args)[$start_idx + i - 1]
      @show $(patvar.name)[i]
      @show $start_idx + i - 1
      @show ($tsym_args)[$start_idx + i - 1] == $(patvar.name)[i]

      ($tsym_args)[$start_idx + i - 1] == $(patvar.name)[i] || @goto backtrack
    end

    # if $(state.current_term_n_remaining) === 0 && $start_idx + length($(patvar.name)) - 1 
    # end

    pc += 0x0001
    @goto compute
  end
end

function match_eq_expr(pat::PatLiteral, state::MatchCompilerState, coordinate, segments_so_far)
  quote
    # @show $(QuoteNode(get_coord(coordinate)))
    if $(pat.value isa Union{Symbol,Expr} ? QuoteNode(pat.value) : pat.value) ==
       $(get_coord(coordinate, segments_so_far))
      pc += 0x0001
      @goto compute
    else
      @goto backtrack
    end
  end
end