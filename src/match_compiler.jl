using Metatheory: alwaystrue
using TermInterface

@kwdef mutable struct MatchCompilerState
  pvars_bound::Vector{Bool}
  program::Vector{Expr} = Expr[]
  term_coord_variables = Pair{Symbol,Any}[]
  segments::Vector{Pair{Symbol,Symbol}} = Pair{Symbol,Symbol}[]
  current_term_has_segment::Bool = false
  current_term_n_remaining::Int = 0
  is_term_operation_patvar = false
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

  push!(state.program, match_yield_expr(state, pvars))

  quote
    function ($(gensym("matcher")))(t, callback::Function, stack::$(OptBuffer{UInt16}))
      # Assign and empty the variables for patterns 
      $([:($var = nothing) for var in setdiff(pvars, first.(state.segments))]...)

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

function match_yield_expr(state::MatchCompilerState, pvars)
  steps = Expr[]
  for (pvar, local_args) in state.segments
    start_idx = Symbol(pvar, :_start)
    end_idx = Symbol(pvar, :_end)
    push!(steps, :($pvar = view($local_args, ($start_idx):($end_idx))))
  end
  push!(steps, :(return callback($(pvars...))))
  Expr(:block, steps...)
end

# ==============================================================
# Term Matchers
# ==============================================================

function make_coord_symbol(coordinate)
  isempty(coordinate) && return :t
  Symbol("t_", join(coordinate, "_"))
end

offset_so_far(segments) = foldl(
  (x, y) -> :($x + $y),
  map(n -> :(length(($(Symbol(n, :_start))):($(Symbol(n, :_end)))) - 1), segments);
  init = 0,
)


function get_coord(coordinate, segments_so_far)
  isempty(coordinate) && return :t

  tsym = make_coord_symbol(coordinate[1:(end - 1)])
  :(@inbounds $(Symbol(tsym, :_args))[$(get_idx(coordinate, segments_so_far))])
end

get_idx(coordinate, segments_so_far) = :($(last(coordinate)) + $(offset_so_far(segments_so_far)))

function match_compile!(pattern::PatExpr, state::MatchCompilerState, coordinate::Vector{Int}, parent_segments)
  tsym = make_coord_symbol(coordinate)
  !isempty(coordinate) && push!(state.term_coord_variables, tsym => nothing)
  push!(state.term_coord_variables, Symbol(tsym, :_op) => nothing)
  push!(state.term_coord_variables, Symbol(tsym, :_args) => nothing)

  pat_op = operation(pattern)
  if pat_op isa PatVar
    state.is_term_operation_patvar = true
    match_compile!(pat_op, state, coordinate, parent_segments)
    state.is_term_operation_patvar = false
  end
  push!(state.program, match_term_expr(pattern, coordinate, parent_segments))

  p_args = arguments(pattern)
  p_arity = length(p_args)
  state.current_term_n_remaining = 0

  segments_so_far = Symbol[]

  for (i, child_pattern) in enumerate(p_args)
    # @show p_arity i
    state.current_term_n_remaining = p_arity - i - count(x -> (x isa PatSegment), @view(p_args[(i + 1):end]))
    match_compile!(child_pattern, state, [coordinate; i], segments_so_far)
  end

  push!(state.program, match_term_expr_closing(pattern, state, [coordinate; p_arity], segments_so_far))
end

function match_compile!(
  patvar::Union{PatVar,PatSegment},
  state::MatchCompilerState,
  coordinate::Vector{Int},
  parent_segments,
)
  tsym = make_coord_symbol(coordinate[1:(end - 1)])
  tsym_args = Symbol(tsym, :_args)

  to_compare = if state.is_term_operation_patvar && patvar isa PatVar
    to_compare = :(operation($tsym))
  else
    get_coord(coordinate, parent_segments)
  end
  instruction = if state.pvars_bound[patvar.idx]
    # Pattern variable with the same Debrujin index has appeared in the  
    # pattern before this (is bound). Just check for equality.
    match_eq_expr(patvar, state, to_compare, coordinate, parent_segments)
  else
    # Variable has not been seen before. Store it
    state.pvars_bound[patvar.idx] = true
    # insert instruction for checking predicates or type.
    match_var_expr(patvar, state, to_compare, coordinate, parent_segments)
  end


  if patvar isa PatSegment
    push!(parent_segments, patvar.name)
    push!(state.segments, patvar.name => tsym_args)
    push!(state.term_coord_variables, Symbol(patvar.name, :_start) => -1)
    push!(state.term_coord_variables, Symbol(patvar.name, :_end) => -2)
    push!(state.term_coord_variables, Symbol(patvar.name, :_n_dropped) => 0)
  end
  push!(state.program, instruction)
end


function match_compile!(p::PatLiteral, state::MatchCompilerState, coordinate::Vector{Int}, segments_so_far)
  to_compare = get_coord(coordinate, segments_so_far)
  push!(state.program, match_eq_expr(p, state, to_compare, coordinate, segments_so_far))
end

# ==============================================================
# Actual Instructions
# ==============================================================

function match_term_op(pattern, tsym, ::Union{Function,DataType})
  t_op = Symbol(tsym, :_op)
  :($t_op == $(pattern.head) || $t_op == $(QuoteNode(pattern.quoted_head)) || @goto backtrack)
end

match_term_op(pattern, tsym, ::Union{Symbol,Expr}) =
  :($(Symbol(tsym, :_op)) == $(QuoteNode(pattern.head)) || @goto backtrack)

match_term_op(::AbstractPat, tsym, op::PatVar) = :($(Symbol(tsym, :_op)) == $(op.name) || @goto backtrack)


function match_term_expr(pattern::PatExpr, coordinate, segments_so_far)
  t = make_coord_symbol(coordinate)
  op_fun = iscall(pattern) ? :operation : :head
  args_fun = iscall(pattern) ? :arguments : :children

  op_guard = match_term_op(pattern, t, operation(pattern))

  quote
    $t = $(get_coord(coordinate, segments_so_far))

    isexpr($t) || @goto backtrack
    iscall($t) === $(iscall(pattern)) || @goto backtrack

    $(Symbol(t, :_op)) = $(op_fun)($t)
    $(Symbol(t, :_args)) = $(args_fun)($t)

    $op_guard

    pc += 0x0001
    @goto compute
  end
end

function match_term_expr_closing(pattern, state, coordinate, segments_so_far)
  tsym = make_coord_symbol(coordinate[1:(end - 1)])
  tsym_args = Symbol(tsym, :_args)

  quote
    if ($(get_idx(coordinate, segments_so_far))) == length($tsym_args)
      pc += 0x0001
      @goto compute
    end
    @goto backtrack
  end
end

match_var_expr_if_guard(patvar::Union{PatVar,PatSegment}, predicate::Function) = :($(predicate)($patvar.name))
match_var_expr_if_guard(patvar::Union{PatVar,PatSegment}, predicate::typeof(alwaystrue)) = true
match_var_expr_if_guard(patvar::Union{PatVar,PatSegment}, T::Type) = :($(patvar.name) isa $T)


function match_var_expr(patvar::PatVar, state::MatchCompilerState, to_compare, coordinate, segments_so_far)
  quote
    $(patvar.name) = $to_compare
    if $(match_var_expr_if_guard(patvar, patvar.predicate))
      pc += 0x0001
      @goto compute
    end
    @goto backtrack
  end
end


function match_var_expr(patvar::PatSegment, state::MatchCompilerState, to_compare, coordinate, segments_so_far)
  tsym = make_coord_symbol(coordinate[1:(end - 1)])
  tsym_args = Symbol(tsym, :_args)
  n_dropped_sym = Symbol(patvar.name, :_n_dropped)


  quote
    start_idx = $(get_idx(coordinate, segments_so_far))
    end_idx = length($tsym_args) - $(state.current_term_n_remaining)

    if end_idx - $n_dropped_sym >= start_idx - 1
      push!(stack, pc)

      # $(patvar.name) = view($tsym_args, start_idx:(end_idx - $n_dropped_sym))
      $(Symbol(patvar.name, :_start)) = start_idx
      $(Symbol(patvar.name, :_end)) = end_idx - $n_dropped_sym


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



function match_eq_expr(patvar::PatVar, state::MatchCompilerState, to_compare, coordinate, segments_so_far)
  quote
    if $(patvar.name) == $to_compare
      pc += 0x0001
      @goto compute
    else
      @goto backtrack
    end
  end
end


function match_eq_expr(patvar::PatSegment, state::MatchCompilerState, to_compare, coordinate, segments_so_far)
  # This method should be called only when a PatSegment is already bound.
  # Get parent term variable name
  # TODO reuse in function, duplicate from get_coord 
  tsym = make_coord_symbol(coordinate[1:(end - 1)])
  tsym_args = Symbol(tsym, :_args)

  start_idx = get_idx(coordinate, segments_so_far)

  previous_local_args = nothing
  for (p, args_sym) in state.segments
    if patvar.name == p
      previous_local_args = args_sym
    end
  end
  @assert !isnothing(previous_local_args)
  previous_start_idx = Symbol(patvar.name, :_start)


  quote
    $start_idx <= length($tsym_args) || @goto backtrack

    for i in 1:length(($(Symbol(patvar.name, :_start))):($(Symbol(patvar.name, :_end))))
      # ($tsym_args)[$start_idx + i - 1] == $(patvar.name)[i] || @goto backtrack
      ($tsym_args)[$start_idx + i - 1] == $previous_local_args[$previous_start_idx + i - 1] || @goto backtrack
    end


    pc += 0x0001
    @goto compute
  end
end

function match_eq_expr(pat::PatLiteral, state::MatchCompilerState, to_compare, coordinate, segments_so_far)
  quote
    if $(pat.value isa Union{Symbol,Expr} ? QuoteNode(pat.value) : pat.value) == $to_compare
      pc += 0x0001
      @goto compute
    else
      @goto backtrack
    end
  end
end