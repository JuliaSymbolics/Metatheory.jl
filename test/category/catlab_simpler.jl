using Catlab
using Catlab.Theories
using Catlab.Syntax

using Metatheory, Metatheory.EGraphs
@metatheory_init ()

# WE HAVE TO REDEFINE THE SYNTAX TO AVOID ASSOCIATIVITY AND N-ARY FUNCTIONS
import Catlab.Theories: id, compose, otimes, ⋅, braid, σ, ⊗, Ob, Hom
@syntax SMC{ObExpr,HomExpr} SymmetricMonoidalCategory begin
end

A, B, C = Ob(SMC, :A, :B, :C)
X, Y, Z = Ob(SMC, :X, :Y, :Z)

f = Hom(:f, A, B)

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
    type_ex = Expr(:call, :→, map(gat_to_expr, ex.type_args)...)
    return Expr(:call, :~, expr, type_ex)
end

function gat_to_expr(ex::HomExpr{:generator})
    expr = Expr(:call, ex.args[1])
    type_ex = Expr(:call, :→, map(gat_to_expr, ex.type_args)...)
    return Expr(:call, :~, expr, type_ex)
end


gat_to_expr(x) = x

gat_to_expr(id(Z)) == :(id(Z)~(Z→Z)) 

gat_to_expr(id(Z) ⋅ f)

gat_to_expr(id(A ⊗ B))

gat_to_expr(id(A) ⊗ id(B))


tt = SMC.theory() |> theory

function axiom_to_rule(theory, axiom)
    lhs = tag_expr(theory, axiom, axiom.left) |> Pattern
    rhs = tag_expr(theory, axiom, axiom.right) |> Pattern
    op = axiom.name
    @assert op == :(==)
    EqualityRule(lhs, rhs)
end



function tag_expr(theory, axiom, expr::Expr)
    # type == axiom.context[x]
    if Meta.isexpr(expr, :call)
        f = expr.args[1]
        rest = expr.args[2:end]

        term = findfirst(x -> x.name == name && length(rest) == length(params), theory.terms)
        

        for (i, arg) in enumerate(rest)

        end 


        ex = Expr(:call, f, 
            map(x -> tag_expr(axiom, x), expr.args[2:end])...)
        return ex
    else 
        return Expr(expr.head, 
            map(x -> tag_expr(axiom, x), expr.args)...)
    end
end

function tag_expr(axiom, x::Symbol)
    type = axiom.context[x]
    if type == :Ob 
        return (x, :Ob) 
    elseif Meta.isexpr(type, :call) && type.args[1] == :Hom
        t = Expr(:call, :→, type.args[2:end]...)
        return (x, t)
    else 
        error("unrecognized GAT type")
    end
end

ax = tt.axioms[7]
tag_expr(ax, ax.left)
tag_expr(ax, ax.right)

axiom_to_rule.(tt.axioms)

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

