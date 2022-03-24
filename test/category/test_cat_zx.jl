using Catlab
using Catlab.Theories

@signature ZXCategory{Ob,Hom} <: DaggerCompactCategory{Ob,Hom} begin
  # Argument α is the phase, usually <: Real
  zphase(A::Ob, α)::(A → A)
  zcopy(A::Ob, α)::(A → (A ⊗ A))
  zdelete(A::Ob, α)::(A → munit())
  zmerge(A::Ob, α)::((A ⊗ A) → A)
  zcreate(A::Ob, α)::(munit() → A)

  xphase(A::Ob, α)::(A → A)
  xcopy(A::Ob, α)::(A → (A ⊗ A))
  xdelete(A::Ob, α)::(A → munit())
  xmerge(A::Ob, α)::((A ⊗ A) → A)
  xcreate(A::Ob, α)::(munit() → A)

  hadamard(A::Ob)::(A → A)
end

# Convenience methods for phaseless spiders.
zcopy(A) = zcopy(A, 0)
zdelete(A) = zdelete(A, 0)
zmerge(A) = zmerge(A, 0)
zcreate(A) = zcreate(A, 0)

xcopy(A) = xcopy(A, 0)
xdelete(A) = xdelete(A, 0)
xmerge(A) = xmerge(A, 0)
xcreate(A) = xcreate(A, 0);

import Catlab.Theories.Ob
@syntax ZXCalculus{ObExpr,HomExpr} ZXCategory begin
  # otimes(A::Ob, B::Ob) = associate_unit(new(A,B), munit)
  # otimes(f::Hom, g::Hom) = associate(new(f,g))
  # compose(f::Hom, g::Hom) = associate(new(f,g; strict=true))
end

using Metatheory, Metatheory.EGraphs

# Custom type APIs for the GATExpr
using TermInterface
TermInterface.operation(t::ObExpr) = :call
TermInterface.arguments(t::ObExpr) = [head(t), t.args...]
TermInterface.operation(t::HomExpr) = :call
TermInterface.arguments(t::HomExpr) = [head(t), t.args...]

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

# Type information will be stored in the metadata
function TermInterface.metadata(t::HomExpr)
  return HomType(t.type_args[1], t.type_args[2], typeof(t).name.module)
end
TermInterface.metadata(t::ObExpr) = ObType(t, typeof(t).name.module)
TermInterface.istree(t::GATExpr) = true
TermInterface.arity(t::GATExpr) = length(arguments(t))

struct CatlabAnalysis <: AbstractAnalysis end
function EGraphs.make(an::Type{CatlabAnalysis}, g::EGraph, n::ENode{T}) where {T}
  !(T <: GATExpr) && return t
  return metadata(n)
end
EGraphs.join(an::Type{CatlabAnalysis}, from, to) = from
EGraphs.islazy(x::Type{CatlabAnalysis}) = false

function infer(t::GATExpr)
  g = EGraph(t)
  analyze!(g, CatlabAnalysis)
  getdata(g[g.root], CatlabAnalysis)
end

function EGraphs.extractnode(g::EGraph, n::ENode{T}, extractor::Function) where {T<:ObExpr}
  @assert n.head == :call
  return metadata(n).ob
end

function EGraphs.extractnode(g::EGraph, n::ENode{T}, extractor::Function) where {T<:HomExpr}
  @assert n.head == :call
  nargs = extractor.(n.args)
  nmeta = metadata(n)
  return nmeta.mod.Hom{nargs[1]}(nargs[2:end], GATExpr[nmeta.dom, nmeta.codom])
end

# function EGraphs.instantiateterm(g::EGraph, pat::PatTerm,  T::Type{H{K}}, sub::Sub, rule::Rule) where {H <: GATExpr, K}
# # TODO
# end

t = Metatheory.@theory begin
  compose(hadamard(A), hadamard(A)) |> begin
    d = getdata(A, Main.CatlabAnalysis)
    return d.mod.id(d.ob)
  end
  compose(f, id(B)) |> begin
    bd = getdata(B, CatlabAnalysis)
    fd = getdata(f, CatlabAnalysis)
    if bd.ob == fd.codom
      return f
    else
      error("TYPE ERROR!")
      return _lhs_expr
    end
  end
  compose(id(A), f) |> begin
    ad = getdata(A, CatlabAnalysis)
    fd = getdata(f, CatlabAnalysis)
    if ad.ob == fd.dom
      return f
    else
      error("TYPE ERROR!")
      return _lhs_expr
    end
  end
end

t[2]

A = Ob(ZXCalculus.Ob, :A)
B = Ob(ZXCalculus.Ob, :B)
f = Hom(:f, A, B)
h = hadamard(A)
c = h ⋅ h
G = EGraph(c)
infer(zdelete(A)).codom == A

analyze!(G, CatlabAnalysis)
saturate!(G, t)
ex = extract!(G, astsize)
ex == id(A)


G = EGraph(f ⋅ id(B))
analyze!(G, CatlabAnalysis)
saturate!(G, t)
ex = extract!(G, astsize)
ex == f

x = id(A) ⋅ f ⋅ id(B)
G = EGraph(x)
analyze!(G, CatlabAnalysis)
saturate!(G, t)
ex = extract!(G, astsize)
ex == f

using Catlab, Catlab.Theories
using Catlab.WiringDiagrams, Catlab.Graphics
using Catlab.Syntax

A, B, C, D, E = Ob(FreeBiproductCategory, :A, :B, :C, :D, :E)
f = Hom(:f, A, B)
g = Hom(:g, B, C)
h = Hom(:h, B, A)
k = Hom(:k, C, B)
x = id(A) ⋅ f ⋅ id(B)

z = x ⊗ f ⊗ ((f ⊗ g) ⋅ braid(B, C) ⋅ (k ⊗ h) ⋅ (delete(B) ⊗ f))
to_composejl(z; orientation = LeftToRight)

drop = munit(FreeCompactClosedCategory.Ob)
delete()
