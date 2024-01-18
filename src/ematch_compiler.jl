module EMatchCompiler

using ..TermInterface
using ..Patterns
using Metatheory.VecExprModule
using Metatheory: lookup_pat, LL, maybelock!, has_constant, get_constant

function ematcher(p::Any, bindings::VecBindings)
  function literal_ematcher(next, g, eclass_id::Id)
    ecid = lookup_pat(g, p)
    if ecid > 0 && ecid === eclass_id
      next(1)
    end
  end
end

checktype(n, T) = istree(n) ? symtype(n) <: T : false

function predicate_ematcher(p::PatVar, T::Type, bindings::VecBindings)
  function type_ematcher(next, g, id::Id)
    eclass = g[id]
    for (enode_idx, n) in enumerate(eclass)
      if !v_istree(n)
        hn = get_constant(g, v_head(n))
        if hn isa T
          bindings[p.idx] = v_pair(id, UInt64(enode_idx))
          next(1)
        end
      end
    end
  end
end

function predicate_ematcher(p::PatVar, pred, bindings::VecBindings)
  function predicate_ematcher(next, g, id::Id)
    eclass = g[id]
    if pred(eclass)
      enode_idx = 0
      # Is this for cycle needed?
      for (j, n) in enumerate(eclass)
        # Find first literal if available
        if !v_istree(n)
          enode_idx = j
          break
        end
      end
      bindings[p.idx] = v_pair(id, UInt64(enode_idx))
      next(1)
    end
  end
end

function ematcher(p::PatVar, bindings::VecBindings)
  pred_matcher = predicate_ematcher(p, p.predicate, bindings)

  function var_ematcher(next, g, id::Id)
    ecid = v_pair_first(bindings[p.idx])
    if ecid > 0
      # Variable is bound
      ecid === id ? next(1) : nothing
    else
      # Variable is not bound, check predicate and bind 
      pred_matcher(next, g, id)
    end
  end
end

Base.@pure @inline checkop(x::Union{Function,DataType}, op) = isequal(x, op) || isequal(nameof(x), op)
Base.@pure @inline checkop(x, op) = isequal(x, op)

@inline has_constant_trick(@nospecialize(g), c::Union{Function,DataType}) =
  has_constant(g, hash(c)) || has_constant(g, hash(nameof(c)))
@inline has_constant_trick(@nospecialize(g), c) = has_constant(g, hash(c))

function canbind(p::PatTerm)
  is_call = is_function_call(p)
  hp = head(p)
  ar = arity(p)
  function canbind(g, n)
    # Assumed to have constant
    v_istree(n) || return false
    hn = get_constant(g, v_head(n))
    v_isfuncall(n) === is_call && checkop(hp, hn) && v_arity(n) === ar
  end
end


function ematcher(p::PatTerm, bindings::VecBindings)
  ematchers::Vector{Function} = [ematcher(cp, bindings) for cp in children(p)]
  hp = head(p)

  if isground(p)
    return function ground_term_ematcher(next, g, eclass_id::Id, ::VecBindings)
      ecid = lookup_pat(g, p)
      if ecid > 0 && ecid === eclass_id
        next(1)
      end
    end
  end

  local_bindings::VecBindings = VecBindings(undef, length(bindings))
  canbindtop = canbind(p)
  function term_ematcher(success, g, eclass_id::Id)
    has_constant_trick(g, hp) || return nothing

    # Define OK variable to avoid boxing issue
    ok = false
    copyto!(local_bindings, bindings) # save backtracking
    for n in g[eclass_id].nodes
      if canbindtop(g, n)
        len = length(ematchers)
        # TODO revise this logic for splat variables
        v_arity(n) === len || @goto skip_node
        copyto!(bindings, local_bindings)
        for i in 1:len
          ok = false
          ematchers[i](g, n[i + VECEXPR_META_LENGTH]) do n_of_matched
            ok = true
          end
          ok || @goto skip_node
        end

        # we have correctly matched the term
        success(1)
      end
      @label skip_node
    end
  end
end


const EMPTY_BINDINGS = Base.ImmutableDict{Int,Tuple{UInt,Int}}()

"""
Substitutions are efficiently represented in memory as immutable dictionaries of tuples of two integers.


TODO rewrite
The format is as follows:

bindings[0] holds 
  1. e-class-id of the node of the e-graph that is being substituted.
  2. the index of the rule in the theory. The rule number should be negative 
    if it's a bidirectional rule and the direction is right-to-left. 

The rest of the immutable dictionary bindings[n>0] represents (e-class id, literal position) at the position of the pattern variable `n`.
"""
function ematcher_yield(p, npvars::Int, direction::Int)
  bindings = VecBindings(undef, npvars)
  em = ematcher(p, bindings)
  function ematcher_yield(g, rule_idx, id)::Int
    n_matches = 0
    # First element of the bindings holds the e-class id of the substitution 
    # and the rule index in the theory, multiplied by -1 if the direction of the rule is inverted (right to left) 
    em(g, id) do n_of_matched
      maybelock!(g) do
        id_rule_pair = v_pair(id, reinterpret(UInt64, rule_idx * direction))
        buffer_needs_n_more_elements = (g.buffer_position + npvars) - length(g.buffer)
        @show buffer_needs_n_more_elements npvars
        if buffer_needs_n_more_elements > 0
          Base._growend!(g.buffer, buffer_needs_n_more_elements)
        end
        g.buffer[g.buffer_position] = id_rule_pair
        copyto!(g.buffer, g.buffer_position + 1, bindings, 1, npvars)
        g.buffer_position += npvars + 1
        n_matches += 1
      end
    end
    n_matches
  end
end

ematcher_yield(p, npvars) = ematcher_yield(p, npvars, 1)

function ematcher_yield_bidir(l, r, npvars::Int)
  eml, emr = ematcher_yield(l, npvars, 1), ematcher_yield(r, npvars, -1)
  function ematcher_yield_bidir(g, rule_idx, id)::Int
    eml(g, rule_idx, id) + emr(g, rule_idx, id)
  end
end

export ematcher_yield, ematcher_yield_bidir

end
