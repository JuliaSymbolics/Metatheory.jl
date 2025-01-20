using Metatheory: alwaystrue
using TermInterface

Base.@kwdef mutable struct MatchCompilerState
  "For each pattern variable, store if it has already been encountered or not"
  pvars_bound::Vector{Bool}
  "List of actual instructions"
  program::Vector{Expr} = Expr[]
  "Pair of variables needed locally in the pattern matcher scope and their initial value"
  variables = Pair{Symbol,Any}[]
  """
  For each segment pattern variable, store the reference to the vector
  that will be used to construct the view.
  """
  segments::Vector{Pair{Symbol,Symbol}} = Pair{Symbol,Symbol}[]

  """
  When matching segment variables, we can count how many non-segment terms
  are remaining in the tail of the pattern term, to avoid matching extra terms
  """
  current_term_n_remaining::Int = 0
end

"""
Entry point for classical pattern matching compiler.

This function, given a `p::AbstractPat` pattern with `n` pattern variables,
returns an `Expr` containing a function definition.

The returned compiled pattern matching function will accept:
  - `_term_being_matched`, being the term that will be matched.
  - `_callback`, a function that will be called on successful match, that should accepts `n` arguments (the number of pattern variables of `p`).
  - `stack`: an [`OptBuffer`](@ref) used to avoid re-allocating the instruction pointer stack.
"""
function match_compile(p::AbstractPat, pvars)::Expr
  state = MatchCompilerState(; pvars_bound = fill(false, length(pvars)))

  # Tree coordinates are a vector of integers.
  # Each index `i` in the vector corresponds to the depth of the term
  # Each value `n` at index `i` selects the `n`-th children of the term at depth i
  # Example: in f(x, g(y, k, h(z))), to get z the coordinate is [2,3,1]
  coordinate = Int[]

  match_compile!(p, state, coordinate, Symbol[])

  push!(state.program, match_yield_expr(state, pvars))

  quote
    function ($(gensym("matcher")))(_term_being_matched, _callback::Function, stack::$(OptBuffer{UInt16}))
      # Assign and empty the variables for patterns
      $([:($(varname(var)) = nothing) for var in setdiff(pvars, first.(state.segments))]...)

      # Initialize the variables needed in the outermost scope (accessible by instruction blocks)
      $([:(local $(Symbol(k)) = $v) for (k, v) in state.variables]...)

      # Backtracking stack
      local stack_idx = 0

      # Instruction 0 is used to return when  the backtracking stack is empty.
      # We start from 1.
      push!(stack, 0x0000)
      local pc = 0x0001

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
    start_idx = Symbol(varname(pvar), :_start)
    end_idx = Symbol(varname(pvar), :_end)
    push!(steps, :($(varname(pvar)) = view($local_args, ($start_idx):($end_idx))))
  end
  push!(steps, :(return _callback($(map(varname, pvars)...))))
  Expr(:block, steps...)
end

# ==============================================================
# Term Matchers
# ==============================================================

function make_coord_symbol(coordinate)::Symbol
  isempty(coordinate) && return :_term_being_matched
  Symbol("_term_being_matched_", join(coordinate, "_"))
end

offset_so_far(segments) = foldl(
  (x, y) -> :($x + $y),
  map(n -> :(length(($(Symbol(varname(n), :_start))):($(Symbol(varname(n), :_end)))) - 1), segments);
  init = 0,
)

function get_coord(coordinate, segments_so_far)
  isempty(coordinate) && return :_term_being_matched
  coord_obj = get_coord_obj(coordinate)
  coord = get_idx(coordinate, segments_so_far)
  quote
    $coord <= length($coord_obj) || @goto backtrack
    $(coord_obj)[$coord]
  end
end

function get_coord_obj(coordinate)
  tsym = make_coord_symbol(coordinate[1:(end - 1)])
  Symbol(tsym, :_args)
end

get_idx(coordinate, segments_so_far) = :($(last(coordinate)) + $(offset_so_far(segments_so_far)))

# TODO FIXME Report on Julialang ?
# This workaround is needed because otherwise pattern variables named `val`
# Are going to clash with @inbounds generated val.
# See this:
# julia> @macroexpand @inbounds v[i:j]
# quote
#     $(Expr(:inbounds, true))
#     local var"#11517#val" = v[i:j]
#     $(Expr(:inbounds, :pop))
#     var"#11517#val"
# end
varname(patvarname::Symbol) = Symbol(:_pvar_, patvarname)

function match_compile!(pattern::PatExpr, state::MatchCompilerState, coordinate::Vector{Int}, parent_segments)
  tsym = make_coord_symbol(coordinate)
  !isempty(coordinate) && push!(state.variables, tsym => nothing)
  push!(state.variables, Symbol(tsym, :_op) => nothing)
  push!(state.variables, Symbol(tsym, :_args) => nothing)

  pat_op = operation(pattern)
  if pat_op isa PatVar
    match_compile!(pat_op, state, coordinate, parent_segments, true)
  end
  push!(state.program, match_term_expr(pattern, coordinate, parent_segments))

  p_args = arguments(pattern)
  p_arity = length(p_args)
  state.current_term_n_remaining = 0

  segments_so_far = Symbol[]

  for (i, child_pattern) in enumerate(p_args)
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
  is_term_operation_patvar = false,
)
  tsym = make_coord_symbol(coordinate[1:(end - 1)])
  tsym_args = Symbol(tsym, :_args)

  to_compare = if is_term_operation_patvar && patvar isa PatVar
    :(operation($tsym))
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
    push!(state.variables, Symbol(varname(patvar.name), :_start) => -1)
    push!(state.variables, Symbol(varname(patvar.name), :_end) => -2)
    push!(state.variables, Symbol(varname(patvar.name), :_n_dropped) => 0)
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

function match_term_op(pattern::PatExpr, tsym::Symbol, ::Union{Function,DataType,UnionAll})
  t_op = Symbol(tsym, :_op)
  :($t_op == $(pattern.head) || $t_op == $(QuoteNode(pattern.quoted_head)) || @goto backtrack)
end

match_term_op(pattern::PatExpr, tsym::Symbol, ::Union{Symbol,Expr}) =
  :($(Symbol(tsym, :_op)) == $(QuoteNode(pattern.head)) || @goto backtrack)

match_term_op(::PatExpr, tsym::Symbol, patvar::PatVar) =
  :($(Symbol(tsym, :_op)) == $(varname(patvar.name)) || @goto backtrack)


function match_term_expr(pattern::PatExpr, coordinate, segments_so_far)
  tsym = make_coord_symbol(coordinate)
  op_fun = iscall(pattern) ? :operation : :head
  args_fun = iscall(pattern) ? :arguments : :children

  op_guard = match_term_op(pattern, tsym, operation(pattern))

  quote
    $tsym = $(get_coord(coordinate, segments_so_far))

    isexpr($tsym) || @goto backtrack
    iscall($tsym) === $(iscall(pattern)) || @goto backtrack

    $(Symbol(tsym, :_op)) = $(op_fun)($tsym)
    $(Symbol(tsym, :_args)) = $(args_fun)($tsym)

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

function match_var_expr(patvar::PatVar, state::MatchCompilerState, to_compare, coordinate, segments_so_far)
  quote
    $(varname(patvar.name)) = $to_compare
    if $(patvar.predicate)($(varname(patvar.name)))
      pc += 0x0001
      @goto compute
    end
    @goto backtrack
  end
end


function match_var_expr(patvar::PatSegment, state::MatchCompilerState, to_compare, coordinate, segments_so_far)
  tsym = make_coord_symbol(coordinate[1:(end - 1)])
  tsym_args = Symbol(tsym, :_args)
  n_dropped_sym = Symbol(varname(patvar.name), :_n_dropped)

  quote
    start_idx = $(get_idx(coordinate, segments_so_far))
    end_idx = length($tsym_args) - $(state.current_term_n_remaining)

    if end_idx - $n_dropped_sym >= start_idx - 1
      push!(stack, pc)

      # $(patvar.name) = view($tsym_args, start_idx:(end_idx - $n_dropped_sym))
      $(Symbol(varname(patvar.name), :_start)) = start_idx
      $(Symbol(varname(patvar.name), :_end)) = end_idx - $n_dropped_sym


      $n_dropped_sym += 1

      $(
        if patvar.predicate != alwaystrue
          quote
            for _i in ($(Symbol(varname(patvar.name), :_start))):($(Symbol(varname(patvar.name), :_end)))
              $(patvar.predicate)(($tsym_args)[_i]) || @goto backtrack
            end
          end
        end
      )

      pc += 0x0001
      @goto compute
    end

    # Restart
    $n_dropped_sym = 0
    @goto backtrack
  end
end



function match_eq_expr(patvar::PatVar, state::MatchCompilerState, to_compare, coordinate, segments_so_far)
  quote
    if isequal($(varname(patvar.name)), $to_compare)
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
  # Start and end indexes in the vector of term arguments that
  # matched on the previous occurrence of the segment variable.
  previous_start_idx = Symbol(varname(patvar.name), :_start)
  previous_end_idx = Symbol(varname(patvar.name), :_end)

  quote
    len = length(($previous_start_idx):($previous_end_idx))
    if $start_idx > length($tsym_args)
      # We're checking a segment variable that was previously bound.
      # We start checking from arguments of term at index `start_idx`.
      # `tsym_args` are the arguments of the term.
      # If `start_idx` is > than the length of the terms, we mean that
      # we have no more space to match.
      # This means that if the previously bound segment variable was empty,
      # and contains no matches, then we can safely proceed.
      # Otherwise we need to fail.
      len == 0 || @goto backtrack
    end
    $start_idx + len - 1 <= length($tsym_args) || @goto backtrack

    for i in 1:len
      # ($tsym_args)[$start_idx + i - 1] == $(patvar.name)[i] || @goto backtrack
      isequal(($tsym_args)[$start_idx + i - 1], $previous_local_args[$previous_start_idx + i - 1]) || @goto backtrack
    end


    pc += 0x0001
    @goto compute
  end
end

function match_eq_expr(pat::PatLiteral, state::MatchCompilerState, to_compare, coordinate, segments_so_far)
  quote
    if isequal($(pat.value isa Union{Symbol,Expr} ? QuoteNode(pat.value) : pat.value), $to_compare)
      pc += 0x0001
      @goto compute
    else
      @goto backtrack
    end
  end
end