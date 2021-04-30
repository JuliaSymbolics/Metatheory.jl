using Catlab
using Catlab.Theories
using Catlab.Syntax

using Metatheory, Metatheory.EGraphs
@metatheory_init ()

# WE HAVE TO REDEFINE THE SYNTAX TO AVOID ASSOCIATIVITY AND N-ARY FUNCTIONS
import Catlab.Theories: id, compose, otimes, ⋅, braid, σ, ⊗, Ob, Hom
@syntax SMC{ObExpr,HomExpr} SymmetricMonoidalCategory begin
end

A, B, C, D = Ob(SMC, :A, :B, :C, :D)
X, Y, Z = Ob(SMC, :X, :Y, :Z)

f = Hom(:f, A, B)
g = Hom(:g, B, C)
h = Hom(:h, C, D)



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


gat_to_expr(x) = x

gat_to_expr(id(Z)) == :(id(Z)~(Z→Z)) 

gat_to_expr(id(Z) ⋅ f)

gat_to_expr(id(A ⊗ B))

gat_to_expr(id(A) ⊗ id(B))

gat_to_expr(compose(compose(f, g), h))

gat_to_expr(f)

tt = SMC.theory() |> theory


# base case
function get_concrete_type_expr(theory, x::Symbol, axiom, loc_ctx = Dict{Code, Code}())
    ctx = axiom.context
    t = ctx[x]
    t === :Ob && (t = x)
    loc_ctx[x] = t
    return t
end

const Code = Union{Symbol, Expr}

function get_concrete_type_expr(theory, x::Expr, axiom, loc_ctx = Dict{Code, Code}())
    #local context
    ctx = axiom.context
    # loc_ctx = Dict{Code, Code}()
    @assert x.head == :call
    f = x.args[1]
    rest = x.args[2:end]
    # recursion case - inductive step (?)
    for a in rest
        t = get_concrete_type_expr(theory, a, axiom, loc_ctx)
        loc_ctx[a] = t
        # println("$a ~ $t")
    end
    # get the corresponding TermConstructor from theory.terms
    # for each arg in `rest`, instantiate the term.params with term.context
    # instantiate term.typ

    loc_ctx[x] = gat_type_inference(theory, f, [loc_ctx[a] for a in rest])
    # println("$x ~ $(loc_ctx[x])")
    return loc_ctx[x]
end

function gat_type_inference(theory, head, args)
    for t in theory.terms
        t.name === head && return gat_type_inference(t, head, args)
    end
    @error "can not find $head in the theory"
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
        return Expr(:call, head, args...)
    else 
        return r.typ
    end
end
function update_bindings!(bindings, template::Expr, target::Expr)
    @assert length(template.args) == length(target.args)
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




ax = tt.axioms[3]
get_concrete_type_expr(tt, ax.left, ax)

tag_expr(:(id(otimes(A,A))), ax, tt) == gat_to_expr(id(otimes(A,A)))

function axiom_to_rule(theory, axiom)
    op = axiom.name
    @assert op == :(==)
    lhs = tag_expr(axiom.left, axiom, tt) |> Pattern
    rhs = tag_expr(axiom.right, axiom, tt) |> Pattern

    pvars = patvars(lhs) ∪ patvars(rhs)
    extravars = setdiff(pvars, patvars(lhs) ∩ patvars(rhs))
    if !isempty(extravars)
        println("EXTRA:", extravars)
        println("LEFT:", patvars(lhs))
        println("RIGHT:", patvars(lhs))

        if extravars ⊆ patvars(lhs)
            println("IS IN LEFT")
            println(lhs)
            println(rhs)
            return RewriteRule(lhs, rhs)
        else 
            return RewriteRule(rhs, lhs)
        end
    end

    # println("$lhs == $rhs")
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

tt = theory(SymmetricMonoidalCategory)
l = (σ(C,B) ⊗ id(A)) ⋅ (id(B) ⊗ σ(C,A)) ⋅ (σ(B,A) ⊗ id(C))
r = (id(C) ⊗ σ(B,A)) ⋅ (σ(C,A) ⊗ id(B)) ⋅ (id(A) ⊗ σ(C,B))

rules = Rule[axiom_to_rule(tt, ax) for ax in tt.axioms] 

l = gat_to_expr(l)
r = gat_to_expr(r)

# push!(rules, RewriteRule(Pattern(l), Pattern(r)))
G = EGraph(l)
addexpr!(G, r)

saturate!(G, rules)
extract!(G, astsize)
areequal(G, rules, l, r)

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

