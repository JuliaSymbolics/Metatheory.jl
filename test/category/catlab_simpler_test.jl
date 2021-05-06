include("catlab_simpler.jl")
using Catlab
using Catlab.Theories
using Catlab.Syntax
using Metatheory, Metatheory.EGraphs
@metatheory_init ()

using Test

# ============================================================
# GATExpr TO TAGGED EXPR
# ============================================================


# WE HAVE TO REDEFINE THE SYNTAX TO AVOID ASSOCIATIVITY AND N-ARY FUNCTIONS
import Catlab.Theories: id, compose, otimes, ⋅, braid, σ, ⊗, Ob, Hom
@syntax SMC{ObExpr,HomExpr} SymmetricMonoidalCategory begin
end

A, B, C, D = Ob(SMC, :A, :B, :C, :D)
X, Y, Z = Ob(SMC, :X, :Y, :Z)

f = Hom(:f, A, B)
g = Hom(:g, B, C)
h = Hom(:h, C, D)

gat_to_expr(x) = x

gat_to_expr(A)

A isa ObExpr{H} where {H}

gat_to_expr(id(Z)) == :(id(Z)~(Hom(Z,Z))) 

gat_to_expr(id(Z) ⋅ f)

gat_to_expr(id(A ⊗ B))

gat_to_expr(id(A) ⊗ id(B))

gat_to_expr(compose(compose(f, g), h))

gat_to_expr(f)

gat_to_expr(A ⊗ B)

# BUG
gat_to_expr(otimes(f, g))



# ============================================================
# Type tagging axioms
# ============================================================

A, B, C, D = Ob(SMC, :A, :B, :C, :D)
X, Y, Z = Ob(SMC, :X, :Y, :Z)

tt = theory(SymmetricMonoidalCategory) ; 
ax = tt.axioms[10] ; 
get_concrete_type_expr(tt, ax.left, ax.context)
tag_expr(ax.left, ax, tt)
ax = tt.axioms[4] 
get_concrete_type_expr(tt, ax.left, ax.context)
tag_expr(ax.left, ax, tt)

tt = theory(Category)

tag_expr(tt.axioms[1].left, tt.axioms[1], tt) == gat_to_expr(compose(compose(f, g), h))


# ====================================================


tt = theory(Category)


A, B, C, D = Ob(SMC, :A, :B, :C, :D)
X, Y, Z = Ob(SMC, :X, :Y, :Z)

f = Hom(:f, A, B)
g = Hom(:g, B, C)
h = Hom(:h, C, D)

rules = gen_theory(tt)
expr = gat_to_expr(id(A) ⋅ id(A) ⋅ f ⋅ id(B))
G = EGraph(expr)
saturate!(G, rules)
@test extract!(G, astsize)  == :(f ~ Hom(A,B))

tt = theory(SymmetricMonoidalCategory)

rules = Rule[axiom_to_rule(tt, ax) for ax in tt.axioms] 

# push!(rules, EqualityRule( @pat(otimes(Hom(A, B), Hom(X, Y))), @pat(Hom(otimes(A, X), otimes(B, Y))) ))

gats = [
    σ(A,B⊗C),
    (σ(A,B) ⊗ id(C)) ⋅ (id(B) ⊗ σ(A,C))
]

exprs = [gat_to_expr(i) for i in gats]

# push!(rules, RewriteRule(Pattern(l), Pattern(r)))
G = EGraph()

ecs = [addexpr!(G, i) for i in exprs]

Metatheory.options.verbose = true
Metatheory.options.printiter = true


saturate!(G, rules)
extract!(G, astsize; root=ecs[2].id)

@test in_same_class(G, ecs[1], ecs[2])


# YANG BAXTER EQUATION

gats = [
    (σ(A,B) ⊗ id(C)) ⋅ (id(B) ⊗ σ(C,A)) ⋅ (σ(B,C) ⊗ id(A)),
    σ(A, B ⊗ C) ⋅ (σ(B,C) ⊗ id(A)),
    (id(A) ⊗ σ(B,C)) ⋅ σ(A, C⊗B),
    (id(A) ⊗ σ(B,C)) ⋅ (σ(A,C) ⊗ id(B)) ⋅ (id(C) ⊗ σ(A,B))
]

exprs = [gat_to_expr(i) for i in gats]

# push!(rules, RewriteRule(Pattern(l), Pattern(r)))
G = EGraph()

ecs = [addexpr!(G, i) for i in exprs]

Metatheory.options.verbose = true
Metatheory.options.printiter = true


saturate!(G, rules, SaturationParams(timeout=1))
extract!(G, astsize; root=ecs[2].id)

[ in_same_class(G, ecs[i], ecs[i+1]) for i in 1:length(gats)-1 ]
    


# ========================================================================================

tt = theory(CartesianCategory)
A, B, C, D = Ob(FreeCartesianCategory, :A, :B, :C, :D)
f = Hom(:f, A, B)
g = Hom(:g, B, C)
h = Hom(:h, C, D)


l = pair(proj1(A, B), proj2(A, B))
r = id(A ⊗ B)

rules = [axiom_to_rule(tt, ax) for ax in tt.axioms] 

l = gat_to_expr(l)
r = gat_to_expr(r)

G = EGraph(l)
rc = addexpr!(G, r)

# TODO identify the rules where there are more patvars on the lhs than the rhs 
# and use regular rewrite rules instead of (==) rules
saturate!(G, rules)
extract!(G, astsize)
extract!(G, astsize; root=rc.id)

l = f ⋅ delete(B)

G = EGraph(gat_to_expr(l))
saturate!(G, rules)
extract!(G, astsize)
#TODO expr to gat

# ====================================================
# TEST 
mu = FreeCartesianCategory.munit(FreeCartesianCategory.Ob)

l = σ(A, mu)
r = id(A)

rules = [axiom_to_rule(tt, ax) for ax in tt.axioms] 

l = gat_to_expr(l)
r = gat_to_expr(r)

G = EGraph(l)
rc = addexpr!(G, r)

# TODO identify the rules where there are more patvars on the lhs than the rhs 
# and use regular rewrite rules instead of (==) rules
saturate!(G, rules)
extract!(G, astsize; root=rc.id)
extract!(G, astsize)

l = σ(A, B) ⋅ σ(B, A)
r = id(A ⊗ B)

rules = [axiom_to_rule(tt, ax) for ax in tt.axioms] 

l = gat_to_expr(l)
r = gat_to_expr(r)

G = EGraph(l)
rc = addexpr!(G, r)

# TODO identify the rules where there are more patvars on the lhs than the rhs 
# and use regular rewrite rules instead of (==) rules
saturate!(G, rules)
extract!(G, astsize; root=rc.id) == extract!(G, astsize)

l = σ(A, mu)
r = id(A)

rules = [axiom_to_rule(tt, ax) for ax in tt.axioms] 

l = gat_to_expr(l)
r = gat_to_expr(r)

G = EGraph(l)
rc = addexpr!(G, r)

# TODO identify the rules where there are more patvars on the lhs than the rhs 
# and use regular rewrite rules instead of (==) rules
saturate!(G, rules)
# extract!(G, astsize; root=rc.id) ==
extract!(G, astsize)

