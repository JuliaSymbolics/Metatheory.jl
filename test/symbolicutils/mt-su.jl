using SymbolicUtils
using Metatheory

import SymbolicUtils: Symbolic, Sym, operation, arguments, Term

TermInterface.istree(t::Symbolic) = SymbolicUtils.istree(t)
TermInterface.gethead(t::Symbolic) = :call 
TermInterface.gethead(t::Sym) = t
TermInterface.getargs(t::Symbolic) = [operation(t), arguments(t)...]
TermInterface.arity(t::Symbolic) = length(arguments(t))

function unflatten_args(f, args, N=4)
    length(args) < N && return Term{Real}(f, args)
    unflatten_args(f, [Term{Real}(f, group)
                                       for group in Iterators.partition(args, N)], N)
end

function TermInterface.preprocess(t::Symbolic)
    if SymbolicUtils.istree(t)
        f = operation(t)
        if f == (+) || f == (*)
            a = arguments(t)
            if length(a) > 2
                return unflatten_args(+, a, 2)
            end
        end
    end
    return t
end

## Test
#

using Metatheory.EGraphs

@metatheory_init ()

g = EGraph()

settermtype!(g, Term)

@syms x

ex = Term{Number}(+, [x, x]) * x

ec = addexpr!(g, ex)

g.root = ec.id

display(g.classes); println()

# (2x) * x => 2 * (x * x) => 2x^2

theory = @methodtheory begin
    (a + a) => 2a
    a * (b * c) == (a * b) * c
    a * a => a^2
end

params = SaturationParams()
saturate!(g, theory, params)

display(g.classes); println()

# 1) search (match) for every rule produce matches of the form 
# (rule, pat, subs, eclass_id)
# optimization: trim rules by scheduling
# subst is a map from (pattern_variable => (eclass_id, literal))
# 2) apply the matchis (write phase) to the e-graph 
# instantiate substitutions to patterns 
# subst(pat) -> add it to the egraph -> merge eclasses for lhs and rhs
# 3) rebuilding: restore invariants for congruence closure in the egrapho
# say that we have enodes representing f(b) and f(c)
# if i set b == c
# we have to go up the graph and propagate, to inform it that f(b) == f(c)

# similarterm(ex, head, args)

extract!(g, astsize) # --> "term" head args

# f(a, b) => a + b

function EGraphs.instantiateterm(g::EGraph, pat::PatTerm, T::Type{<:Symbolic}, children) 
    if pat.head == :call 
        Term{Real}(children[1], children[2:end])
    end 
end


# Define an extraction method dispatching on MyExpr
function EGraphs.extractnode(n::ENode{<:Symbolic}, extractor::Function)
    # (foo, bar, baz) = n.metadata
    # extracted arguments
    ret_args = [extractor(a) for a in n.args]
    if n.head == :call 
        return Term(ret_args[1], ret_args[2:end])
    end
end