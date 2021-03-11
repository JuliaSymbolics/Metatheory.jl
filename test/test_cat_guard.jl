using Metatheory
using Metatheory.EGraphs
using Metatheory.Util
# Description here:
# https://www.philipzucker.com/metatheory-progress/


# https://github.com/AlgebraicJulia/Catlab.jl/blob/ce2fde9c63a8aab65cf2a7697f43cd24e5e00b3a/src/theories/Monoidal.jl#L127

cat_rules = @theory begin
    f ⋅ id(b) => f
    id(a) ⋅ f => f

    #f => f ⋅ id(dom(type(f)))
    #f => id(cod(type(f))) ⋅ f

    a ⊗ₒ munit() => a
    munit() ⊗ₒ a => a

    #a => a ⊗ₒ munit() 
    #a => munit() ⊗ₒ a

    f ⋅ (g ⋅ h) == (f ⋅ g) ⋅ h


end

monoidal_rules = @theory begin
    id(munit()) ⊗ₘ f => f
    f ⊗ₘ id(munit()) => f
    a ⊗ₒ (b ⊗ₒ c) == (a ⊗ₒ b) ⊗ₒ c
    f ⊗ₘ (h ⊗ₘ j) == (f ⊗ₘ h) ⊗ₘ j
    id(a ⊗ₒ b) == id(a) ⊗ₘ id(b)

    (f ⊗ₘ p) ⋅ (g ⊗ₘ q) |>
    # future metatheory macros will clean this up
    begin
        fcod = addexpr!(_egraph, :(cod(type($f))))
        gdom = addexpr!(_egraph, :(dom(type($g))))
        pcod = addexpr!(_egraph, :(cod(type($p))))
        qdom = addexpr!(_egraph, :(dom(type($q))))
        if (fcod == gdom && pcod == qdom)
            :(($f ⋅ $g) ⊗ₘ ($p ⋅ $q))
        else
            :(($f ⊗ₘ $p) ⋅ ($g ⊗ₘ $q))
        end
    end

    (f ⋅ g) ⊗ₘ (p ⋅ q) => (f ⊗ₘ p) ⋅ (g ⊗ₘ q)
end



sym_rules = @theory begin
    σ(a, b) ⋅ σ(b, a) == id(a ⊗ₒ b)
    (σ(a, b) ⊗ₘ id(c)) ⋅ (id(b) ⊗ₘ σ(a, c)) == σ(a, b ⊗ₒ c)
    (id(a) ⊗ₘ σ(b, c)) ⋅ (σ(a, c) ⊗ₘ id(b)) == σ(a ⊗ₒ b, c)

    (f ⊗ₘ h) ⋅ σ(a, b) |> begin
        fcod = addexpr!(_egraph, :(cod(type($f)))).id
        hcod = addexpr!(_egraph, :(cod(type($h)))).id
        if fcod == a && hcod == b
            :(σ(dom(type($f)), dom(type($h))) ⋅ ($h ⊗ₘ $f))
        else
            :(($f ⊗ₘ $h) ⋅ σ($a, $b))
        end
    end


    σ(c, d) ⋅ (h ⊗ₘ f) |> begin
        fdom = addexpr!(_egraph, :(dom(type($f)))).id
        hdom = addexpr!(_egraph, :(dom(type($h)))).id
        if fdom == c && hdom == d
            :(($f ⊗ₘ $h) ⋅ σ(cod(type($f)), cod(type($h))))
        else
            :(σ($c, $d) ⋅ ($h ⊗ₘ $f))
        end
    end

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

    Δ(a) ⋅ (f ⊗ₘ k) |> begin
        a_id = find(_egraph, a)
        if (
            addexpr!(_egraph, :(dom(type($f)))).id == a_id &&
            addexpr!(_egraph, :(dom(type($k)))).id == a_id
        )
            :(pair($f, $k))
        else
            :(Δ($a) ⋅ ($f ⊗ₘ $k))
        end
    end


    pair(f, k) => Δ(dom(type(f))) ⋅ (f ⊗ₘ k)
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
macro calc(e...)
    theory = eval(e[1])
    e = rmlines(e[2])
    @assert e.head == :block
    for (a, b) in zip(e.args[1:end-1], e.args[2:end])
        println(a, " =? ", b)
        @time println(areequal(theory, a, b; timeout = 40))
    end
end

# Get the Julia motor hummin'
@calc rules begin

    ((⋄(a) ⊗ₘ ⋄(b)) ⋅ σ(munit(), munit()))
    (σ(a, b) ⋅ (⋄(b) ⊗ₘ ⋄(a)))

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
