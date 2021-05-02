using Catlab
using Catlab.Theories
using Catlab.Syntax

using Metatheory, Metatheory.EGraphs
@metatheory_init ()

# GATExpr => normal Expr in MT
function gat_to_expr(ex::ObExpr{:generator})
    @assert length(ex.args) == 1
    return ex.args[1]
end
function gat_to_expr(ex::ObExpr{H}) where {H}
    return Expr(:call, head(ex), map(gat_to_expr, ex.args)...)
end
function gat_to_expr(ex::HomExpr{H}) where {H}
    @assert length(ex.type_args) == 2
    expr = Expr(:call, head(ex), map(gat_to_expr, ex.args)...)
    type_ex = Expr(:call, :Hom, map(gat_to_expr, ex.type_args)...)
    return Expr(:call, :~, expr, type_ex)
end
function gat_to_expr(ex::HomExpr{:generator})
    f = ex.args[1]
    type_ex = Expr(:call, :Hom, map(gat_to_expr, ex.type_args)...)
    return Expr(:call, :~, f, type_ex)
end

const Code = Union{Symbol, Expr}


# infer type of morphisms and objects
# a morphism f: A → B will be typed as f ~ Hom(A, B)
# an object A will be typed as Ob(A)
function get_concrete_type_expr(theory, x::Symbol, ctx, type_tags = Dict{Code, Code}())
    t = ctx[x]
    t === :Ob && (t = Expr(:call, :Ob, x))
    type_tags[x] = t
    return t
end
function get_concrete_type_expr(theory, x::Expr, ctx, type_tags = Dict{Code, Code}())
    @assert x.head == :call
    f = x.args[1]
    rest = x.args[2:end]
    # recursion case - inductive step (?)
    for a in rest
        t = get_concrete_type_expr(theory, a, ctx, type_tags)
        type_tags[a] = t
        # println("$a ~ $t")
    end
    # get the corresponding TermConstructor from theory.terms
    # for each arg in `rest`, instantiate the term.params with term.context
    # instantiate term.typ

    type_tags[x] = gat_type_inference(theory, f, [type_tags[a] for a in rest])
    # println("$x ~ $(type_tags[x])")
    return type_tags[x]
end

function is_context_match(t, head, args)
    t.name !== head && return false
    n = length(t.params)
    n != length(args) && return false
    for i = 1:n
        if t.context[t.params[i]] === :Ob 
            if (args[i] isa Symbol) || args[i].args[1] !== :Ob
                return false
            end
        else
            if !(args[i] isa Symbol) && args[i].args[1] === :Ob
                return false
            end
        end
    end
    return true
end

function gat_type_inference(theory, head, args)
    for t in theory.terms
        if is_context_match(t, head, args)
            @show t, head, args
            return gat_type_inference(t, head, args)
    end
end
    @show theory, head, args
    @error "can not find $(Expr(:call, head, args...)) in the theory"
end
function gat_type_inference(t::GAT.TermConstructor, head, args)
    @assert length(t.params) == length(args) && t.name === head
    bindings = Dict()
    for i = 1:length(args)
        template = t.context[t.params[i]]
        template === :Ob && (template = t.params[i])
        # @show template
        update_bindings!(bindings, template, args[i])
    end
    # @show bindings
    r = GAT.replace_types(bindings, t)
    if r.typ == :Ob 
        return Expr(:call, :Ob, Expr(:call, head, args...))
    else 
        return r.typ
    end
end
function update_bindings!(bindings, template::Expr, target::Expr)
    for i = 1:length(template.args)
        update_bindings!(bindings, template.args[i], target.args[i])
    end
end
function update_bindings!(bindings, template, target)
    bindings[template] = target
end


function tag_expr(x::Expr, axiom, theory)
    t = get_concrete_type_expr(theory, x, axiom)
    start = x.head == :call ? 2 : 1 

    nargs = Any[tag_expr(y, axiom, theory) for y in x.args[start:end]]

    if start == 2
        pushfirst!(nargs, x.args[1])
    end

    z = Expr(x.head, nargs...)

    (t === :Ob || t == x) && (return z)
    :($z ~ $t)
end

function tag_expr(x::Symbol, axiom, theory)
    t = get_concrete_type_expr(theory, x, axiom)
    (t === :Ob || t == x) && (return x)
    return (t == x ? x : :($x ~ $t))
end


import Catlab.Theories: id, compose, otimes, ⋅, braid, σ, ⊗, Ob, Hom
@syntax SMC{ObExpr,HomExpr} SymmetricMonoidalCategory begin
end

A, B, C, D = Ob(SMC, :A, :B, :C, :D)
X, Y, Z = Ob(SMC, :X, :Y, :Z)

tt = theory(SymmetricMonoidalCategory)
ax = tt.axioms[10]
get_concrete_type_expr(tt, ax.left, ax.context)
ax = tt.axioms[4]
get_concrete_type_expr(tt, ax.left, ax.context)

function axiom_to_rule(theory, axiom)
    lhs = tag_expr(axiom.left, axiom, tt) |> Pattern
    rhs = tag_expr(axiom.right, axiom, tt) |> Pattern

    # println("$lhs == $rhs")
    op = axiom.name
    @assert op == :(==)
    EqualityRule(lhs, rhs)
end

tt = theory(Category)

tag_expr(tt.axioms[1].left, tt.axioms[1], tt) == gat_to_expr(compose(compose(f, g), h))


using Catlab
using Catlab.Theories
using Metatheory
using Metatheory.EGraphs

tt = theory(Category)
rules = [axiom_to_rule(tt, ax) for ax in tt.axioms] 
expr = gat_to_expr(id(A) ⋅ id(A) ⋅ f ⋅ id(B))
G = EGraph(expr)
saturate!(G, rules)
extract!(G, astsize) == :(f ~ Hom(A,B))
# ====================================================
# TEST 


function simplify(ex, syntax)
    t = gen_theory(syntax)
    g = EGraph(ex)
    analyze!(g, CatlabAnalysis)
    params=SaturationParams(timeout=1)
    saturate!(g, t, params; mod=@__MODULE__)
    extract!(g, astsize)
end

Metatheory.options.printiter = true

ex = f ⋅ id(B)
simplify(ex, SMC) == f

ex = id(A) ⋅ f ⋅ id(B)
simplify(ex, SMC) == f

ex = σ(A,B) ⋅ σ(B,A)
simplify(ex, SMC) == id(A ⊗ B)


# ======================================================
# another test

using Catlab.Graphics

l = (σ(C,B) ⊗ id(A)) ⋅ (id(B) ⊗ σ(C,A)) ⋅ (σ(B,A) ⊗ id(C))
r = (id(C) ⊗ σ(B,A)) ⋅ (σ(C,A) ⊗ id(B)) ⋅ (id(A) ⊗ σ(C,B))

to_graphviz(l)
to_graphviz(r)

g = EGraph()
analyze!(g, CatlabAnalysis)
l_ec = addexpr!(g, l)
r_ec = addexpr!(g, r)

in_same_class(g, l_ec, r_ec)

saturate!(g, gen_theory(SMC), SaturationParams(timeout=1, eclasslimit=6000); mod=@__MODULE__)

ll = extract!(g, astsize; root=l_ec.id) 
rr = extract!(g, astsize; root=r_ec.id) 

# ======================================================
# another test

# WE HAVE TO REDEFINE THE SYNTAX TO AVOID ASSOCIATIVITY AND N-ARY FUNCTIONS
import Catlab.Theories: id, compose, otimes, ⋅, braid, σ, ⊗, Ob, Hom, pair, proj1, proj2
@syntax BPC{ObExpr,HomExpr} BiproductCategory begin
end
A, B, C = Ob(BPC, :A, :B, :C)
f = Hom(:f, A, B)
k = Hom(:k, B, C)


l = Δ(A) ⋅ (delete(A) ⊗ id(A)) 
r = id(A)


g = EGraph(l)
analyze!(g, CatlabAnalysis)


saturate!(g, gen_theory(BPC), SaturationParams(timeout=1, eclasslimit=6000); mod=@__MODULE__)

extract!(g, astsize)

# ======================================================
# another test

l = σ(A, B ⊗ C)
# r = σ(B,A) ⊗ id(C)
r = (σ(A,B) ⊗ id(C)) ⋅ (id(B) ⊗ σ(A,C))
# r = σ(B ⊗ C, A)

to_composejl(l)
to_composejl(r)

g = EGraph(ex)
analyze!(g, CatlabAnalysis)
l_ec = addexpr!(g, l)
r_ec = addexpr!(g, r)


saturate!(g, gen_theory(SMC), SaturationParams(timeout=1, eclasslimit=6000); mod=@__MODULE__)

extract!(g, astsize; root=l_ec.id)

extract!(g, astsize; root=r_ec.id)




# ====================================================
# TEST 
cc = gen_theory(FreeCartesianCategory)

A, B, C = Ob(FreeCartesianCategory, :A, :B, :C)
f = Hom(:f, A, B)

g = EGraph()
analyze!(g, CatlabAnalysis)
ex = id(A) ⊗ id(B)
to_composejl(ex)

l_ec = addexpr!(g, ex)
saturate!(g, cc, SaturationParams(timeout=2); mod=@__MODULE__)
extract!(g, astsize; root=l_ec.id)


ex = pair(proj1(A, B), proj2(A, B))
to_composejl(ex)
r_ec = addexpr!(g, ex)
saturate!(g, cc; mod=@__MODULE__)
extract!(g, astsize; root=r_ec.id)

