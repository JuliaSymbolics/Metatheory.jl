using Catlab
using Catlab.Theories
using Catlab.Syntax

using Metatheory, Metatheory.EGraphs
using TermInterface

@metatheory_init ()


abstract type CatType end
struct ObType <: CatType
    ob
    mod
end
struct HomType <: CatType
    dom
    codom
    mod
end

# Custom type APIs for the GATExpr
using Metatheory.TermInterface
TermInterface.gethead(t::ObExpr) = :call
TermInterface.getargs(t::ObExpr) = [head(t), t.args...]
TermInterface.gethead(t::HomExpr) = :call
TermInterface.getargs(t::HomExpr) = [head(t), t.args...]

# Type information will be stored in the metadata
function TermInterface.metadata(t::HomExpr)
    return HomType(t.type_args[1], t.type_args[2], typeof(t).name.module)
end
TermInterface.metadata(t::ObExpr) = ObType(t, typeof(t).name.module)
TermInterface.isterm(t::GATExpr) = true
TermInterface.arity(t::GATExpr) = length(getargs(t))

struct CatlabAnalysis <: AbstractAnalysis end
function EGraphs.make(an::Type{CatlabAnalysis}, g::EGraph, n::ENode{T}) where T
    !(T <: GATExpr) && return T
    return metadata(n)
end
EGraphs.join(an::Type{CatlabAnalysis}, from, to) = from
EGraphs.islazy(x::Type{CatlabAnalysis}) = false

function infer(t::GATExpr)
    g = EGraph(t)
    analyze!(g, CatlabAnalysis)
    getdata(geteclass(g, g.root), CatlabAnalysis)
end

function EGraphs.extractnode(g::EGraph, n::ENode{T}, extractor::Function) where {T <: ObExpr}
    @assert n.head == :call
    return metadata(n).ob
end

function EGraphs.extractnode(g::EGraph, n::ENode{T}, extractor::Function) where {T <: HomExpr}
    @assert n.head == :call
    nargs = extractor.(n.args)
    nmeta = metadata(n)
    return nmeta.mod.Hom{nargs[1]}(nargs[2:end], GATExpr[nmeta.dom, nmeta.codom])
end

# ==============================================================================

using MatchCore

datasym(x::Symbol) = Symbol(String(x) * "_data")
extrsym(x::Symbol) = Symbol(String(x) * "_extr")

function build_rhs(x::Expr, pvars, mod)
    if Meta.isexpr(x, :call) 
        if x.args[1] == :munit && length(x.args) == 1
            mod.munit(mod.Ob)
        else
            Expr(x.head, getfield(mod, x.args[1]), map(y -> build_rhs(y, pvars, mod), x.args[2:end])...)
        end
    else 
        Expr(x.head, map(y -> build_rhs(y, pvars, mod), x.args)...)
    end
end
function build_rhs(x, pvars, mod)
    if x ∈ pvars
        extrsym(x)
    else
        x
    end
end
function gen_rule(axiom::Catlab.GAT.AxiomConstructor, mod; righttoleft=false)
    # left to right
    @assert axiom.name == :(==)

    ax_left = axiom.left
    ax_right = axiom.right
    if righttoleft
        ax_left = axiom.right
        ax_right = axiom.left
    end

    lhs = Pattern(ax_left, mod)
    l_pvars = patvars(lhs) 
    
    rhs = build_rhs(ax_right, l_pvars, mod)
    # println(rhs)

    lines = []

    eq_ctx = Dict{Symbol, Vector{Any}}()
    for patvar in l_pvars
        # retrieve the catlab data
        data_var = datasym(patvar)
        data_expr = :($data_var = getdata($patvar, CatlabAnalysis))
        push!(lines, data_expr)
        # push!(lines, :(println($data_var)))


        extr_var = extrsym(patvar)
        extr_expr = :($extr_var = extract!(_egraph, astsize; root=($patvar).id))
        push!(lines, extr_expr)
        # push!(lines, :(println($extr_var)))


        ctxval = axiom.context[patvar]
        # TODO use GATTheory.types
        @smatch ctxval begin
            :Ob => begin 
                check_type_line = :(!($data_var isa ObType) && (return _lhs_expr))
                aset = get!(()->[], eq_ctx, patvar)
                push!(lines, check_type_line)
                push!(aset, :($(data_var).ob))
            end
            :(Hom($(A::Symbol), $(B::Symbol))) => begin
                aset = get!(()->[], eq_ctx, A)
                bset = get!(()->[], eq_ctx, B)
                push!(aset, :($(data_var).dom))
                push!(bset, :($(data_var).codom))
                check_type_line = :(!($data_var isa HomType) && (return _lhs_expr))
                push!(lines, check_type_line)
            end
            _ => error("unrecognized GAT type context $patvar => $ctxval")
        end
    end

    for (ctxvar, eqset) in eq_ctx
        if ctxvar ∉ l_pvars
            push!(lines, :($ctxvar = $(eqset[1])))
        end
    end

    # conjunction of equalities needed
    conjunction = []

    for (ctxvar, eqset) in eq_ctx
        unique!(eqset)
        c = []
        if length(eqset) < 2 
            continue
        end
        fst = first(eqset)
        for other in eqset[2:end]
            push!(c, :($fst == $other))
        end 
        append!(conjunction, c)
    end



    if !isempty(conjunction)
        conj_expr = foldl((x,y) -> :($x && $y), conjunction)

        the_big_if = :(if $conj_expr
            # WORKAROUND FOR RuntimeGeneratedFunctions.jl `id` bug
            # return $(evalmod).eval($(Meta.quot(ax_right))) 
            return $rhs
        else 
            return _lhs_expr end) |> Metatheory.Util.rmlines
        push!(lines, the_big_if)
    else 
        push!(lines, :(return $rhs))
    end

    block = Expr(:block, lines...)

    DynamicRule(lhs, block)
end

# test 
tt = theory(SymmetricMonoidalCategory)
ax = tt.axioms[2]

gen_rule(tt.axioms[2], @__MODULE__)

# Generate a theory from a syntax system
function gen_theory(m::Module)
    gat_theory = theory(m.theory())
    mt_theory = Rule[]
    for axiom in gat_theory.axioms
        push!(mt_theory, gen_rule(axiom, m))
        push!(mt_theory, gen_rule(axiom, m, righttoleft=true))
    end
    mt_theory
end


# ====================================================
# TEST 

# WE HAVE TO REDEFINE THE SYNTAX TO AVOID ASSOCIATIVITY AND N-ARY FUNCTIONS
import Catlab.Theories: id, compose, otimes, ⋅, braid, σ, ⊗, Ob, Hom
@syntax SMC{ObExpr,HomExpr} SymmetricMonoidalCategory begin
end

function simplify(ex, syntax)
    t = gen_theory(syntax)
    g = EGraph(ex)
    analyze!(g, CatlabAnalysis)
    params=SaturationParams(timeout=3)
    saturate!(g, t, params)
    extract!(g, astsize)
end

Metatheory.options.printiter = true
Metatheory.options.verbose = true

A, B, C = Ob(SMC, :A, :B, :C)
f = Hom(:f, A, B)

ex = f ⋅ id(B)
simplify(ex, SMC) == f

ex = id(A) ⋅ id(A) ⋅ f ⋅ id(B)
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
l_ec, _ = addexpr!(g, l)
r_ec, _ = addexpr!(g, r)

in_same_class(g, l_ec, r_ec)

saturate!(g, gen_theory(SMC), SaturationParams(timeout=1, eclasslimit=6000))

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


saturate!(g, gen_theory(BPC), SaturationParams(timeout=1, eclasslimit=6000))

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
l_ec, _ = addexpr!(g, l)
r_ec, _ = addexpr!(g, r)


saturate!(g, gen_theory(SMC), SaturationParams(timeout=1, eclasslimit=6000))

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

l_ec, _ = addexpr!(g, ex)
saturate!(g, cc, SaturationParams(timeout=2))
extract!(g, astsize; root=l_ec.id)


ex = pair(proj1(A, B), proj2(A, B))
to_composejl(ex)
r_ec, _ = addexpr!(g, ex)
saturate!(g, cc)
extract!(g, astsize; root=r_ec.id)

