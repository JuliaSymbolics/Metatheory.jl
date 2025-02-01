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
function buffer_readable(g, limit, ematch_buffer)
  k = length(ematch_buffer)

  while k > limit
    delimiter = ematch_buffer.v[k]
    @assert delimiter == 0xffffffffffffffff
    n = k - 1

    next_delimiter_idx = 0
    n_elems = 0
    for i in n:-1:1
      n_elems += 1
      if ematch_buffer.v[i] == 0xffffffffffffffff
        n_elems -= 1
        next_delimiter_idx = i
        break
      end
    end

    match_info = ematch_buffer.v[next_delimiter_idx + 1]
    id = v_pair_first(match_info)
    rule_idx = reinterpret(Int, v_pair_last(match_info))
    rule_idx = abs(rule_idx)

    bindings = @view ematch_buffer.v[(next_delimiter_idx + 2):n]

    print("$id E-Classes: ", map(x -> reinterpret(Int, v_pair_first(x)), bindings))
    print(" Nodes: ", map(x -> reinterpret(Int, v_pair_last(x)), bindings), "\n")

    k = next_delimiter_idx
  end
end