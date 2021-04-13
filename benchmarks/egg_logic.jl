include("eggify.jl")
using Metatheory.Classic
using Metatheory.Util
using Metatheory.Library
using Metatheory.EGraphs.Schedulers

Metatheory.options.verbose = true
# Metatheory.options.printiter = true

@metatheory_init

or_alg = @theory begin
    ((p ∨ q) ∨ r)       ==  (p ∨ (q ∨ r))
    (p ∨ q)             ==  (q ∨ p)
    (p ∨ p)             =>  p
    (p ∨ true)          =>  true
    (p ∨ false)         =>  p
end

and_alg = @theory begin
    ((p ∧ q) ∧ r)       ==  (p ∧ (q ∧ r))
    (p ∧ q)             ==  (q ∧ p)
    (p ∧ p)             =>  p
    (p ∧ true)          =>  p
    (p ∧ false)         =>  false
end

comb = @theory begin
    # DeMorgan
    ¬(p ∨ q)            ==  (¬p ∧ ¬q)
    ¬(p ∧ q)            ==  (¬p ∨ ¬q)
    # distrib
    (p ∧ (q ∨ r))       ==  ((p ∧ q) ∨ (p ∧ r))
    (p ∨ (q ∧ r))       ==  ((p ∨ q) ∧ (p ∨ r))
    # absorb
    (p ∧ (p ∨ q))       =>  p
    (p ∨ (p ∧ q))       =>  p
    # complement
    (p ∧ (¬p ∨ q))      =>  p ∧ q
    (p ∨ (¬p ∧ q))      =>  p ∨ q
end

negt = @theory begin
    (p ∧ ¬p)            =>  false
    (p ∨ ¬(p))          =>  true
    ¬(¬p)               ==  p
end

impl = @theory begin
    (p == ¬p)           =>  false
    (p == p)            =>  true
    (p == q)            =>  (¬p ∨ q) ∧ (¬q ∨ p)
    (p => q)            =>  (¬p ∨ q)
end

fold = @theory begin
    (true == false)     =>   false
    (false == true)     =>   false
    (true == true)      =>   true
    (false == false)    =>   true
    (true ∨ false)      =>   true
    (false ∨ true)      =>   true
    (true ∨ true)       =>   true
    (false ∨ false)     =>   false
    (true ∧ true)       =>   true
    (false ∧ true)      =>   false
    (true ∧ false)      =>   false
    (false ∧ false)     =>   false
    ¬(true)             =>   false
    ¬(false)            =>   true
end

theory = or_alg ∪ and_alg ∪ comb ∪ negt ∪ impl ∪ fold


query = :(¬(((¬p ∨ q) ∧ (¬r ∨ s)) ∧ (p ∨ r)) ∨ (q ∨ s))

###########################################

params = SaturationParams(timeout=22, eclasslimit=3051,
    scheduler=ScoredScheduler)#, schedulerparams=(1000,5, Schedulers.exprsize))

for i ∈ 1:2
    G = EGraph( query )
    report = saturate!(G, theory, params)
    ex = extract!(G, astsize)
    println( "Best found: $ex")
    println(report)
end


open("src/main.rs", "w") do f
    write(f, rust_code(theory, query, params))
end
