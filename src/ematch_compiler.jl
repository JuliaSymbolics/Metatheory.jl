module EMatchCompiler

using ..TermInterface
using ..Patterns
using Metatheory:
  to_expr,
  islist,
  car,
  cdr,
  assoc,
  drop_n,
  lookup_pat,
  LL,
  maybelock!,
  has_constant,
  get_constant,
  enode_istree,
  enode_is_function_call,
  enode_flags,
  enode_head,
  enode_children,
  enode_arity

function ematcher(p::Any)
  function literal_ematcher(next, g, data, bindings)
    !islist(data) && return
    ecid = lookup_pat(g, p)
    @show p ecid
    if ecid > 0 && ecid == car(data)
      next(bindings, 1)
    end
  end
end

checktype(n, T) = istree(n) ? symtype(n) <: T : false

function predicate_ematcher(p::PatVar, T::Type)
  function type_ematcher(next, g, data, bindings)
    !islist(data) && return
    id = car(data)
    eclass = g[id]
    for (enode_idx, n) in enumerate(eclass)
      if !enode_istree(n)
        hn = get_constant(g, enode_head(n))
        if hn isa T
          next(assoc(bindings, p.idx, (id, enode_idx)), 1)
        end
      end
    end
  end
end

function predicate_ematcher(p::PatVar, pred)
  function predicate_ematcher(next, g, data, bindings)
    !islist(data) && return
    id::UInt = car(data)
    eclass = g[id]
    if pred(eclass)
      enode_idx = 0
      # Is this for cycle needed?
      for (j, n) in enumerate(eclass)
        # Find first literal if available
        if !enode_istree(n)
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

  function var_ematcher(next, g, data, bindings)
    id = car(data)
    ecid = get(bindings, p.idx, 0)[1]
    if ecid > 0
      ecid == id ? next(bindings, 1) : nothing
    else
      # Variable is not bound, check predicate and bind 
      pred_matcher(next, g, data, bindings)
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
    enode_istree(n) || return false
    hn = get_constant(g, enode_head(n))
    enode_is_function_call(n) === is_call && checkop(hp, hn) && enode_arity(n) === ar
  end
end


function ematcher(p::PatTerm)
  ematchers = map(ematcher, children(p))
  hp = head(p)

  if isground(p)
    return function ground_term_ematcher(next, g, data, bindings)
      !islist(data) && return
      ecid = lookup_pat(g, p)
      if ecid > 0 && ecid == car(data)
        next(bindings, 1)
      end
    end
  end

  canbindtop = canbind(p)
  function term_ematcher(success, g, data, bindings)
    !islist(data) && return nothing
    has_constant_trick(g, hp) || return nothing

    function loop(children_eclass_ids, bindings′, ematchers′)
      if !islist(ematchers′)
        # term is empty
        if !islist(children_eclass_ids)
          # we have correctly matched the term
          return success(bindings′, 1)
        end
        return nothing
      end
      car(ematchers′)(g, children_eclass_ids, bindings′) do b, n_of_matched # next
        # recursion case:
        # take the first matcher, on success,
        # keep looping by matching the rest 
        # by removing the first n matched elements 
        # from the term, with the bindings, 
        loop(drop_n(children_eclass_ids, n_of_matched), b, cdr(ematchers′))
      end
    end

    for n in g[car(data)].nodes
      println(p)
      println(n)
      println(get_constant(g, enode_head(n)))
      println(to_expr(g, n))
      println(canbindtop(g, n))
      if canbindtop(g, n)
        loop(LL(enode_children(n), 1), bindings, ematchers)
      end
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
    em(g, (id,), EMPTY_BINDINGS) do b, n
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
