#### Pattern matching
### Matching procedures
# A matcher is a function which takes 3 arguments
# 1. Callback: takes arguments Dictionary × Number of elements matched
# 2. Expression
# 3. Vector of matches debrujin-indexed by pattern variables
#

using Metatheory: islist, car, cdr, assoc, drop_n, take_n

function matcher(p::PatLiteral)
  function literal_matcher(next, data, bindings)
    islist(data) && isequal(car(data), p.value) ? next(bindings, 1) : nothing
  end
end

function matcher(slot::PatVar)
  pred = slot.predicate
  if slot.predicate isa Type
    pred = x -> typeof(x) <: slot.predicate
  end
  function slot_matcher(next, data, bindings)
    !islist(data) && return
    val = get(bindings, slot.idx, nothing)
    if val !== nothing
      if isequal(val, car(data))
        return next(bindings, 1)
      end
    else
      # Variable is not bound, first time it is found
      # check the predicate     
      if pred(car(data))
        next(assoc(bindings, slot.idx, car(data)), 1)
      end
    end
  end
end

# returns n == offset, 0 if failed
function trymatchexpr(data, value, n)
  if !islist(value)
    return n
  elseif islist(value) && islist(data)
    if !islist(data)
      # didn't fully match
      return nothing
    end

    while isequal(car(value), car(data))
      n += 1
      value = cdr(value)
      data = cdr(data)

      if !islist(value)
        return n
      elseif !islist(data)
        return nothing
      end
    end

    return !islist(value) ? n : nothing
  elseif isequal(value, data)
    return n + 1
  end
end

function matcher(segment::PatSegment)
  function segment_matcher(success, data, bindings)
    val = get(bindings, segment.idx, nothing)
    if val !== nothing
      n = trymatchexpr(data, val, 0)
      if !isnothing(n)
        success(bindings, n)
      end
    else
      res = nothing

      for i in length(data):-1:0
        subexpr = take_n(data, i)

        if segment.predicate(subexpr)
          res = success(assoc(bindings, segment.idx, subexpr), i)
          !isnothing(res) && break
        end
      end

      return res
    end
  end
end

# Try to match both against a function symbol or a function object at the same time.
# Slows compile time down a bit but lets this matcher work at the same time on both purely symbolic Expr-like object.
# Execution time should not be affected.
# and SymbolicUtils-like objects that store function references as operations.
function operation_matcher(f::Union{Function,DataType,UnionAll})
  checkop(x) = isequal(x, f) || isequal(x, nameof(f))
  function operation_matcher(next, data, bindings)
    h = car(data)
    if islist(data) && checkop(h)
      next(bindings, 1)
    else
      nothing
    end
  end
end

operation_matcher(x::Any) = matcher(PatLiteral(x))
operation_matcher(x::PatVar) = matcher(x)

function is_call_matcher(pat_iscall::Bool)
  function is_call_matcher(next, data, bindings)
    islist(data) && pat_iscall === iscall(data) ? next(bindings, 0) : nothing
  end
end

function matcher(term::PatExpr)
  pat_iscall = iscall(term)
  h = operation(term)
  is_call_m = is_call_matcher(pat_iscall)
  # Hacky solution for function objects matching against their `nameof`
  matchers = [is_call_m; operation_matcher(h); map(matcher, arguments(term))]

  function term_matcher(success, data, bindings)
    !islist(data) && return nothing
    !isexpr(car(data)) && return nothing

    function loop(term, bindings′, matchers′) # Get it to compile faster
      # Base case, no more matchers
      if !islist(matchers′)
        # term is empty
        if !islist(term)
          # we have correctly matched the term
          return success(bindings′, 1)
        end
        return nothing
      end
      car(matchers′)(term, bindings′) do b, n
        # recursion case:
        # take the first matcher, on success,
        # keep looping by matching the rest 
        # by removing the first n matched elements 
        # from the term, with the bindings, 
        loop(drop_n(term, n), b, cdr(matchers′))
      end
    end

    loop(car(data), bindings, matchers) # Try to eat exactly one term
  end
end

function instantiate(left, pat::PatExpr, mem)
  ntail = []
  for parg in arguments(pat)
    instantiate_arg!(ntail, left, parg, mem)
  end
  maketerm(typeof(left), operation(pat), ntail)
end

function instantiate(left::Expr, pat::PatExpr, mem)
  ntail = []
  if iscall(pat)
    for parg in arguments(pat)
      instantiate_arg!(ntail, left, parg, mem)
    end
    op = operation(pat)
    op_name = op isa Union{Function,DataType} ? nameof(op) : op
    maketerm(Expr, :call, [op_name; ntail])
  else
    for parg in children(pat)
      instantiate_arg!(ntail, left, parg, mem)
    end
    maketerm(Expr, head(pat), ntail)
  end
end

instantiate_arg!(acc, left, parg::PatSegment, mem) = append!(acc, instantiate(left, parg, mem))
instantiate_arg!(acc, left, parg::AbstractPat, mem) = push!(acc, instantiate(left, parg, mem))

instantiate(_, pat::PatLiteral, mem) = pat.value
instantiate(_, pat::Union{PatVar,PatSegment}, mem) = mem[pat.idx]

