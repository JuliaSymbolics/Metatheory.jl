using Metatheory: alwaystrue
using TermInterface

@kwdef mutable struct MatchCompilerState
  pvars_bound::Vector{Bool}
  program::Vector{Expr} = Expr[]
  term_coord_variables = Symbol[]
  segments::Vector{Symbol} = Symbol[]
  current_term_has_segment = false
end

function match_compile(p, pvars, direction)
  npvars = length(pvars)

  state = MatchCompilerState(; pvars_bound = fill(false, npvars))

  # Tree cordinates are a vector of integers.
  # Each index `i` in the vector corresponds to the depth of the term 
  # Each value `n` at index `i` selects the `n`-th children of the term at depth i
  # Example: in f(x, g(y, k, h(z))), to get z the coordinate is [2,3,1]
  coordinate = Int[]

  match_compile!(p, state, coordinate)
  push!(state.program, :(return callback($(pvars...))))

  quote
    Base.@propagate_inbounds function ($(gensym("matcher")))(t, callback::Function, stack::OptBuffer{UInt16})
      # Assign and empty the variables for patterns 
      $([:($var = nothing) for var in pvars]...)
      $([:($v = nothing) for v in state.term_coord_variables]...)

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
    offset_sym = Symbol(tsym, :_offset)
    :($(last(coordinate)) + $offset_sym)
  else
    last(coordinate)
  end
  :($(Symbol(tsym, :_args))[$idx])
end

function match_compile!(pattern::PatExpr, state::MatchCompilerState, coordinate::Vector{Int})
  push!(state.program, match_term_expr(pattern, coordinate, state.current_term_has_segment))
  t_sym = make_coord_symbol(coordinate)
  !isempty(coordinate) && push!(state.term_coord_variables, t_sym)
  push!(state.term_coord_variables, Symbol(t_sym, :_op))
  push!(state.term_coord_variables, Symbol(t_sym, :_args))
  # The sum of how many terms have been taken by segments

  state.current_term_has_segment = false

  for (i, child_pattern) in enumerate(arguments(pattern))
    match_compile!(child_pattern, state, [coordinate; i])
  end

  state.current_term_has_segment && push!(state.term_coord_variables, Symbol(t_sym, :_offset))

  state.current_term_has_segment = false
end


function match_compile!(patvar::Union{PatVar,PatSegment}, state::MatchCompilerState, coordinate::Vector{Int})
  # Mark that the current term has a segment variable
  instruction = if state.pvars_bound[patvar.idx]
    # Pattern variable with the same Debrujin index has appeared in the  
    # pattern before this (is bound). Just check for equality.
    match_eq_expr(patvar, coordinate, state.current_term_has_segment)
  else
    # Variable has not been seen before. Store it
    state.pvars_bound[patvar.idx] = true
    # insert instruction for checking predicates or type.
    match_var_expr(patvar, coordinate, state.current_term_has_segment)
  end
  patvar isa PatSegment && (state.current_term_has_segment = true)
  push!(state.program, instruction)
end


function match_compile!(p::PatLiteral, state::MatchCompilerState, coordinate::Vector{Int})
  push!(state.program, match_eq_expr(p, coordinate, state.current_term_has_segment))
end

function match_compile!(p::AbstractPat, state::MatchCompilerState, coordinate::Vector{Int})
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

    isexpr($t) || @goto backtrack
    iscall($t) == $(iscall(pattern)) || @goto backtrack

    $(Symbol(t, :_op)) = $(op_fun)($t)
    $(Symbol(t, :_args)) = $(args_fun)($t)

    $op_guard

    pc += 0x0001
    @goto compute
  end
end

match_var_expr_if_guard(patvar::PatVar, predicate::Function) = :($(predicate)($patvar.name))
match_var_expr_if_guard(patvar::PatVar, predicate::typeof(alwaystrue)) = true
match_var_expr_if_guard(patvar::PatVar, T::Type) = :($(patvar.name) isa $T)


function match_var_expr(patvar::PatVar, coordinate, current_term_has_segment)
  quote
    $(patvar.name) = $(get_coord(coordinate, current_term_has_segment))
    if $(match_var_expr_if_guard(patvar, patvar.predicate))
      pc += 0x0001
      @goto compute
    end
    @goto backtrack
  end
end

function match_var_expr(patvar::PatSegment, coordinate, current_term_has_segment)
  tsym = make_coord_symbol(coordinate[1:(end - 1)])
  tsym_args = Symbol(tsym, :_args)
  offset_sym = Symbol(tsym, :_offset)

  remaining

  start_idx = if current_term_has_segment
    :($(last(coordinate)) + $offset_sym)
  else
    last(coordinate)
  end


  quote
    push!(stack, pc)

    start_idx = $start_idx

    for end_idx in ((length($tsym_args) - $remaining)):-1:(start_idx)
      $(patvar.name) = view($tsym_args, start_idx:end_idx)

      if $(match_var_expr_if_guard(patvar, patvar.predicate))
        pc += 0x0001
        @goto compute
      end
    end

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
    if $(pat.value) == $(get_coord(coordinate, current_term_has_segment))
      pc += 0x0001
      @goto compute
    else
      @goto backtrack
    end
  end
end