using Metatheory
using Metatheory.EGraphs
using Metatheory.Util
# Description here:
# https://www.philipzucker.com/metatheory-progress/

Metatheory.options.verbose = false
Metatheory.options.printiter = false

# https://github.com/AlgebraicJulia/Catlab.jl/blob/ce2fde9c63a8aab65cf2a7697f43cd24e5e00b3a/src/theories/Monoidal.jl#L127

cat_rules = @theory begin
    f ⋅ id(b) => f
    id(a) ⋅ f => f
    f == f ⋅ id(cod(type(f)))
    f == id(dom(type(f))) ⋅ f

    a ⊗ₒ munit() == a
    munit() ⊗ₒ a == a

    f ⋅ (g ⋅ h) == (f ⋅ g) ⋅ h
end

monoidal_rules = @theory begin
    id(munit()) ⊗ₘ f => f
    f ⊗ₘ id(munit()) => f
    a ⊗ₒ (b ⊗ₒ c) == (a ⊗ₒ b) ⊗ₒ c
    f ⊗ₘ (h ⊗ₘ j) == (f ⊗ₘ h) ⊗ₘ j
    id(a ⊗ₒ b) == id(a) ⊗ₘ id(b)

    $( MultiPatRewriteRule(@pat((f ⊗ₘ p) ⋅ (g ⊗ₘ q)), @pat((f ⋅ g) ⊗ₘ (p ⋅ q)), 
        [PatEquiv(@pat(cod(type(f))), @pat(dom(type(g)))), PatEquiv(@pat(cod(type(p))), @pat(dom(type(q))))]) )

    (f ⋅ g) ⊗ₘ (p ⋅ q) => (f ⊗ₘ p) ⋅ (g ⊗ₘ q)
end



sym_rules = @theory begin
    σ(a, b) ⋅ σ(b, a) == id(a ⊗ₒ b)
    (σ(a, b) ⊗ₘ id(c)) ⋅ (id(b) ⊗ₘ σ(a, c)) == σ(a, b ⊗ₒ c)
    (id(a) ⊗ₘ σ(b, c)) ⋅ (σ(a, c) ⊗ₘ id(b)) == σ(a ⊗ₒ b, c)

    $( MultiPatRewriteRule(@pat((f ⊗ₘ h) ⋅ σ(a, b)), @pat(σ(dom(type(f)), dom(type(h))) ⋅ (h ⊗ₘ f)),
        [PatEquiv(@pat(cod(type(f))), @pat(a)), PatEquiv(@pat(cod(type(h))), @pat(b))]) )


    $( MultiPatRewriteRule(@pat(σ(c, d) ⋅ (h ⊗ₘ f)), @pat((f ⊗ₘ h) ⋅ σ(cod(type(f)), cod(type(h)))),
        [PatEquiv(@pat(dom(type(f))), PatVar(:c)), PatEquiv(@pat(dom(type(f))), PatVar(:d))]))

    # these rules arer not catlab
    σ(a, munit()) == id(a)
    σ(munit(), a) == id(a)
    σ(munit(), munit()) => id(munit() ⊗ₒ munit())

end



diag_rules = @theory begin
    Δ(a) ⋅ (⋄(a) ⊗ₘ id(a)) == id(a)
    Δ(a) ⋅ (id(a) ⊗ₘ ⋄(a)) == id(a)
    Δ(a) ⋅ σ(a, a) == Δ(a)

    (Δ(a) ⊗ₘ Δ(b)) ⋅ (id(a) ⊗ₘ σ(a, b) ⊗ₘ id(b)) == Δ(a ⊗ₒ b)

    Δ(a) ⋅ (Δ(a) ⊗ₘ id(a)) == Δ(a) ⋅ (id(a) ⊗ₘ Δ(a))
    ⋄(a ⊗ₒ b) == ⋄(a) ⊗ₘ ⋄(b)

    Δ(munit()) == id(munit())
    ⋄(munit()) == id(munit())
end


cart_rules = @theory begin
    $( MultiPatRewriteRule(@pat(Δ(a) ⋅ (f ⊗ₘ k)), @pat(pair(f,k)), 
        [PatEquiv(@pat(dom(type(f))), @pat(dom(type(k))))]))

    pair(f, k) == Δ(dom(type(f))) ⋅ (f ⊗ₘ k)
    proj1(a, b) == id(a) ⊗ₘ ⋄(b)
    proj2(a, b) == ⋄(a) ⊗ₘ id(b)
    f ⋅ ⋄(b) => ⋄(dom(type(f)))
    # Has to invent f. Hard to fix.
    # ⋄(b) => f ⋅ ⋄(b)

    f ⋅ Δ(b) => Δ(dom(type(f))) ⋅ (f ⊗ₘ f)
    Δ(a) ⋅ (f ⊗ₘ f) => f ⋅ Δ(cod(type(f)))
end


typing_rules = @theory begin
    dom(hom(a, b)) => a
    cod(hom(a, b)) => b
    type(id(a)) => hom(a, a)
    type(f ⋅ g) => hom(dom(type(f)), cod(type(g)))
    type(f ⊗ₘ g) => hom(dom(type(f)) ⊗ₒ dom(type(g)), cod(type(f)) ⊗ₒ cod(type(g)))
    type(a ⊗ₒ b) => :ob
    type(munit()) => :ob
    type(σ(a, b)) => hom(a ⊗ₒ b, b ⊗ₒ a)
    type(⋄(a)) => hom(a, munit())
    type(Δ(a)) => hom(a, a ⊗ₒ a)
    type(pair(f, g)) => hom(dom(type(f)), cod(type(f)) ⊗ₒ cod(type(g)))
    type(proj1(a, b)) => hom(a ⊗ₒ b, a)
    type(proj2(a, b)) => hom(a ⊗ₒ b, b)
end


rules = typing_rules ∪ cat_rules ∪ monoidal_rules ∪ sym_rules ∪ diag_rules ∪ cart_rules ∪ typing_rules


# A goofy little helper macro
# Taking inspiration from Lean/Dafny/Agda
using Metatheory.Util
using Metatheory.EGraphs.Schedulers
macro calc(e...)
    theory = eval(e[1])
    e = rmlines(e[2])
    @assert e.head == :block

    trues = Bool[]

    for (a, b) in zip(e.args[1:end-1], e.args[2:end])
        # println(a, " =? ", b)
        params = SaturationParams(
            timeout=12, 
            eclasslimit=8000,
            scheduler=SimpleScheduler
            )
        g = EGraph()
        ta = addexpr!(g, :(type(a)))
        tao = addexpr!(g, :(:ob))
        merge!(g, ta.id, tao.id)

        eq = @time areequal(g, theory, a, b; params=params)
        push!(trues, eq)
        println(eq)
        #  WOULD WORK IF COST FUNCTION IS SIMILARITY TO OTHER FUN
        # if !eq
        #     i = 0
        #     while !eq && i < 4
        #         ga = EGraph(a); gb = EGraph(b)
        #         ga_extr = addanalysis!(ga, ExtractionAnalysis, astsize)
        #         gb_extr = addanalysis!(gb, ExtractionAnalysis, astsize)
        #         @time saturate!(ga, theory; timeout = 9)
        #         @time saturate!(gb, theory; timeout = 9)
        #
        #         new_a = extract!(ga, ga_extr)
        #         new_b = extract!(gb, gb_extr)
        #         println("i = $i \nnew a = $new_a \nnew b = $new_b")
        #         eq = @time areequal(theory, new_a, new_b; timeout = 9)
        #         i += 1
        #     end
        #
        #     if !eq && i == 4
        #         return false
        #     end
        # end
    end
    all(trues)
end

@calc rules begin
    id(a ⊗ₒ b)
    id(a) ⊗ₘ id(b)
    (Δ(a) ⋅ (id(a) ⊗ₘ ⋄(a))) ⊗ₘ id(b)
    (Δ(a) ⋅ (id(a) ⊗ₘ ⋄(a))) ⊗ₘ (Δ(b) ⋅ (⋄(b) ⊗ₘ id(b)))
    (Δ(a) ⊗ₘ Δ(b)) ⋅ ((id(a) ⊗ₘ ⋄(a)) ⊗ₘ (⋄(b) ⊗ₘ id(b)))
    (Δ(a) ⊗ₘ Δ(b)) ⋅ (id(a) ⊗ₘ (⋄(a) ⊗ₘ ⋄(b)) ⊗ₘ id(b))
    (Δ(a) ⊗ₘ Δ(b)) ⋅ (id(a) ⊗ₘ ((⋄(a) ⊗ₘ ⋄(b)) ⋅ σ(munit(), munit())) ⊗ₘ id(b))
    (Δ(a) ⊗ₘ Δ(b)) ⋅ ((id(a) ⊗ₘ (σ(a, b) ⋅ (⋄(b) ⊗ₘ ⋄(a))) ⊗ₘ id(b)))
    (Δ(a) ⊗ₘ Δ(b)) ⋅ ((id(a) ⊗ₘ (σ(a, b) ⋅ (⋄(b) ⊗ₘ ⋄(a))) ⊗ₘ id(b)))
    (Δ(a) ⊗ₘ Δ(b)) ⋅ ((id(a) ⋅ id(a)) ⊗ₘ (σ(a, b) ⋅ (⋄(b) ⊗ₘ ⋄(a))) ⊗ₘ id(b))
    (Δ(a) ⊗ₘ Δ(b)) ⋅ ((id(a) ⊗ₘ σ(a, b) ⊗ₘ id(b)) ⋅ (id(a) ⊗ₘ (⋄(b) ⊗ₘ ⋄(a)) ⊗ₘ id(b)))
    Δ(a ⊗ₒ b) ⋅ (id(a) ⊗ₘ (⋄(b) ⊗ₘ ⋄(a)) ⊗ₘ id(b))
    Δ(a ⊗ₒ b) ⋅ (id(a) ⊗ₘ (⋄(b) ⊗ₘ ⋄(a)) ⊗ₘ id(b))
    Δ(a ⊗ₒ b) ⋅ (proj1(a, b) ⊗ₘ proj2(a, b))
    pair(proj1(a, b), proj2(a, b))
end

# shorter proof also accepted
@calc rules begin
    id(a ⊗ₒ b)
    (Δ(a) ⊗ₘ Δ(b)) ⋅ ((id(a) ⊗ₘ (σ(a, b) ⋅ (⋄(b) ⊗ₘ ⋄(a))) ⊗ₘ id(b)))
    pair(proj1(a, b), proj2(a, b))
end

# shorter proof not quite there
@calc rules begin
    id(a ⊗ₒ b)
    pair(proj1(a, b), proj2(a, b))
end

@calc rules begin
    id(a ⊗ₒ b)
    id(a) ⊗ₘ id(b)
    (Δ(a) ⋅ (id(a) ⊗ₘ ⋄(a))) ⊗ₘ id(b)
    (Δ(a) ⋅ (id(a) ⊗ₘ ⋄(a))) ⊗ₘ (Δ(b) ⋅ (⋄(b) ⊗ₘ id(b)))
    (Δ(a) ⊗ₘ Δ(b)) ⋅ ((id(a) ⊗ₘ ⋄(a)) ⊗ₘ (⋄(b) ⊗ₘ id(b)))
    (Δ(a) ⊗ₘ Δ(b)) ⋅ (id(a) ⊗ₘ (⋄(a) ⊗ₘ ⋄(b)) ⊗ₘ id(b))
    (Δ(a) ⊗ₘ Δ(b)) ⋅ (id(a) ⊗ₘ ((⋄(a) ⊗ₘ ⋄(b)) ⋅ σ(munit(), munit())) ⊗ₘ id(b))
    (Δ(a) ⊗ₘ Δ(b)) ⋅ ((id(a) ⊗ₘ (σ(a, b) ⋅ (⋄(b) ⊗ₘ ⋄(a))) ⊗ₘ id(b)))
    (Δ(a) ⊗ₘ Δ(b)) ⋅ ((id(a) ⊗ₘ (σ(a, b) ⋅ (⋄(b) ⊗ₘ ⋄(a))) ⊗ₘ id(b)))
    (Δ(a) ⊗ₘ Δ(b)) ⋅ ((id(a) ⋅ id(a)) ⊗ₘ (σ(a, b) ⋅ (⋄(b) ⊗ₘ ⋄(a))) ⊗ₘ id(b))
    (Δ(a) ⊗ₘ Δ(b)) ⋅ ((id(a) ⊗ₘ σ(a, b) ⊗ₘ id(b)) ⋅ (id(a) ⊗ₘ (⋄(b) ⊗ₘ ⋄(a)) ⊗ₘ id(b)))
    Δ(a ⊗ₒ b) ⋅ (id(a) ⊗ₘ (⋄(b) ⊗ₘ ⋄(a)) ⊗ₘ id(b))
    Δ(a ⊗ₒ b) ⋅ (id(a) ⊗ₘ (⋄(b) ⊗ₘ ⋄(a)) ⊗ₘ id(b))
    Δ(a ⊗ₒ b) ⋅ (proj1(a, b) ⊗ₘ proj2(a, b))
    pair(proj1(a, b), proj2(a, b))
end

Metatheory.options.verbose = true
Metatheory.options.printiter = true
Metatheory.options.multithreading = false

G = EGraph( :(pair(proj1(a, b), proj2(a, b))))
params = SaturationParams(timeout=5)
saturate!(G, rules, params )
ex = extract!(G, astsize)

G.classes