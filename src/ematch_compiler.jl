module EMatchCompiler

using TermInterface
using ..Patterns
using ..VecExprModule
using Metatheory: assoc, lookup_pat, LL, maybelock!, has_constant, get_constant

function ematcher(p::Any)
  function literal_ematcher(next, g, eclass_id::Id, bindings)
    ecid = lookup_pat(g, p)
    if ecid > 0 && ecid === eclass_id
      next(bindings, 1)
    end
  end
end

checktype(n, T) = isexpr(n) ? symtype(n) <: T : false

function predicate_ematcher(p::PatVar, T::Type)
  function type_ematcher(next, g, id::Id, bindings)
    eclass = g[id]
    for (enode_idx, n) in enumerate(eclass)
      if !v_isexpr(n)
        hn = get_constant(g, v_head(n))
        if hn isa T
          next(assoc(bindings, p.idx, (id, enode_idx)), 1)
        end
      end
    end
  end
end

function predicate_ematcher(p::PatVar, pred)
  function predicate_ematcher(next, g, id::Id, bindings)
    eclass = g[id]
    if pred(g, eclass)
      enode_idx = 0
      # TODO Is this for cycle needed?
      for (j, n) in enumerate(eclass)
        # Find first literal if available
        if !v_isexpr(n)
          enode_idx = j
          break
        end
      end
      next(assoc(bindings, p.idx, (id, enode_idx)), 1)
    end
  end
end

function ematcher(p::PatVar)
  pred_matcher = predicate_ematcher(p, p.predicate)

  function var_ematcher(next, g, id::Id, bindings)
    ecid = get(bindings, p.idx, 0)[1]
    if ecid > 0
      ecid === id ? next(bindings, 1) : nothing
    else
      # Variable is not bound, check predicate and bind 
      pred_matcher(next, g, id, bindings)
    end
  end
end

function ematcher(p::PatExpr)
  ematchers::Vector{Function} = map(ematcher, arguments(p))
  op = operation(p)

  if isground(p)
    return function ground_term_ematcher(next, g, eclass_id::Id, bindings)
      ecid = lookup_pat(g, p)
      if ecid > 0 && ecid === eclass_id
        next(bindings, 1)
      end
    end
  end

  function term_ematcher(success, g, eclass_id::Id, bindings)
    has_constant(g, v_head(p.n)) || has_constant(g, p.quoted_head_hash) || return nothing

    # Define OK variable to avoid boxing issue
    ok = false
    new_bindings = bindings
    for n in g[eclass_id].nodes
      # TODO WARNING: HASH COLLISIONS (very unlikely)
      v_flags(n) == v_flags(p.n) || @goto skip_node
      v_signature(n) == v_signature(p.n) || @goto skip_node
      v_head(n) == v_head(p.n) || (v_head(n) == p.quoted_head_hash || @goto skip_node)

      len = length(ematchers)
      # TODO revise this logic for splat variables
      v_arity(n) === len || @goto skip_node
      # n_args = v_children(n)
      new_bindings = bindings
      for i in 1:len
        ok = false
        ematchers[i](g, n[i + VECEXPR_META_LENGTH], new_bindings) do b, n_of_matched
          new_bindings = b
          ok = true
        end
        ok || @goto skip_node
      end

      # we have correctly matched the term
      success(new_bindings, 1)
      @label skip_node
    end
  end
end


const EMPTY_BINDINGS = Base.ImmutableDict{Int,Tuple{UInt,Int}}()

"""
Substitutions are efficiently represented in memory as immutable dictionaries of tuples of two integers.

The format is as follows:

bindings[0] holds 
  1. e-class-id of the node of the e-graph that is being substituted.
  2. the index of the rule in the theory. The rule number should be negative 
    if it's a bidirectional rule and the direction is right-to-left. 

The rest of the immutable dictionary bindings[n>0] represents (e-class id, literal position) at the position of the pattern variable `n`.
"""
function ematcher_yield(p, npvars::Int, direction::Int)
  em = ematcher(p)
  function ematcher_yield(g, rule_idx, id)::Int
    n_matches = 0
    em(g, id, EMPTY_BINDINGS) do b, n
      maybelock!(g) do
        push!(g.buffer, assoc(b, 0, (id, rule_idx * direction)))
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
