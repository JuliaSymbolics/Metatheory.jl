module EMatchCompiler

using ..TermInterface
using ..Patterns
using Metatheory:
  Id,
  to_expr,
  islist,
  assoc,
  drop_n,
  lookup_pat,
  LL,
  maybelock!,
  has_constant,
  get_constant,
  v_istree,
  v_isfuncall,
  v_flags,
  v_head,
  v_children,
  v_arity

function ematcher(p::Any)
  function literal_ematcher(next, g, eclass_id::Id, bindings)
    ecid = lookup_pat(g, p)
    if ecid > 0 && ecid === eclass_id
      next(bindings, 1)
    end
  end
end

checktype(n, T) = istree(n) ? symtype(n) <: T : false

function predicate_ematcher(p::PatVar, T::Type)
  function type_ematcher(next, g, id::Id, bindings)
    eclass = g[id]
    for (enode_idx, n) in enumerate(eclass)
      if !v_istree(n)
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


function ematcher(p::PatTerm)
  ematchers::Vector{Function} = map(ematcher, children(p))
  hp = head(p)

  if isground(p)
    return function ground_term_ematcher(next, g, eclass_id::Id, bindings)
      ecid = lookup_pat(g, p)
      if ecid > 0 && ecid === eclass_id
        next(bindings, 1)
      end
    end
  end

  canbindtop = canbind(p)
  function term_ematcher(success, g, eclass_id::Id, bindings)
    has_constant_trick(g, hp) || return nothing

    # function loop(children_eclass_ids, bindings′, ematchers′)
    #   if !islist(ematchers′)
    #     # term is empty
    #     if !islist(children_eclass_ids)
    #       # we have correctly matched the term
    #       return success(bindings′, 1)
    #     end
    #     return nothing
    #   end
    #   car(ematchers′)(g, children_eclass_ids, bindings′) do b, n_of_matched # next
    #     # recursion case:
    #     # take the first matcher, on success,
    #     # keep looping by matching the rest 
    #     # by removing the first n matched elements 
    #     # from the term, with the bindings, 
    #     loop(drop_n(children_eclass_ids, n_of_matched), b, cdr(ematchers′))
    #   end
    # end

    for n in g[eclass_id].nodes
      if canbindtop(g, n)
        # loop(LL(v_children(n), 1), bindings, ematchers)
        len = length(ematchers)
        # TODO revise this logic for splat variables
        v_arity(n) === len || @goto skip_node
        n_args = v_children(n)
        new_bindings = bindings
        for i in 1:len
          ok = false
          ematchers[i](g, n_args[i], new_bindings) do b, n_of_matched
            new_bindings = b
            ok = true
          end
          ok || @goto skip_node
        end

        # we have correctly matched the term
        success(new_bindings, 1)
      end
      @label skip_node
      # loop(LL(v_children(n), 1), bindings, ematchers)
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
