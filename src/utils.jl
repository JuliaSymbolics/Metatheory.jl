using Base: ImmutableDict
using TimerOutputs

const binarize_ops = [:(+), :(*), (+), (*)]

function cleanast(e::Expr)
  # TODO better line removal
  if e.head === :block
    return Expr(e.head, filter(x -> !(x isa LineNumberNode), e.args)...)
  end

  # Binarize
  if iscall(e)
    op = e.args[1]
    if op ∈ binarize_ops && length(e.args) > 3
      return foldl((x, y) -> Expr(:call, op, x, y), @view e.args[2:end])
    end
  end
  return e
end

const being_timed = Ref{Bool}(false)

macro timer(name, expr)
  :(
    if being_timed[]
      @timeit $(esc(name)) $(esc(expr))
    else
      $(esc(expr))
    end
  )
end

# TODO adjust
"Useful for debugging: prints the content of the e-graph match buffer in readable format."
function buffer_readable(g, theory, ematch_buffer::OptBuffer{UInt64}, limit = length(ematch_buffer))
  k = 1
  while k < limit
    id = ematch_buffer[k]
    rule_idx = reinterpret(Int, ematch_buffer[k + 1])
    isliteral_bitvec = ematch_buffer[k + 2]
    direction = sign(rule_idx)
    rule_idx = abs(rule_idx)
    rule = theory[rule_idx]

    bind_start = k + 3

    bind_end = bind_start + length(rule.patvars) - 1

    bindings = @view ematch_buffer[bind_start:bind_end]

    # Print literal hashes as UInt64 hashes, and e-class IDs as ints with %
    print(
      "Rule $rule_idx on %$id bindings: [",
      join(map(enumerate(bindings)) do (i, x)
        v_bitvec_check(isliteral_bitvec, i) ? "$x" : "%$(reinterpret(Int64, x))"
      end, ", "),
      "]\n",
    )

    k = bind_end + 1
  end
end